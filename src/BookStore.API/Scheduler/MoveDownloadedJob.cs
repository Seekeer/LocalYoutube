using API.FilmDownload;
using FileStore.Domain;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using System.Linq;
using Polly;
using Quartz;
using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using API.Controllers;
using AngleSharp.Media;

namespace Infrastructure.Scheduler
{
    [DisallowConcurrentExecution]
    public class MoveDownloadedJob : JobBase
    {
        private readonly IServiceProvider _service;
        private readonly AppConfig _appConfig;

        public MoveDownloadedJob(IServiceProvider service, AppConfig appConfig)
        {
            _service = service;
            _appConfig = appConfig;
        }

        protected override async Task Execute()
        {
            await this.MoveFiles();
        }

        public async Task MoveFiles()
        {
            var db = _service.GetService<VideoCatalogDbContext>();
            var fileManager = new FileManager(db, new FileManagerSettings(_appConfig.RootDownloadFolder, _appConfig.RootFolder,  true));
            var movedFiles = 0;
            var torrentManager = _service.GetService<IRuTrackerUpdater>();

            var files = db.Files.Where(x => x.Path.Contains(_appConfig.RootDownloadFolder) && !x.IsDownloading)
                .Include(x => x.VideoFileExtendedInfo).OrderBy(x => x.Duration).ToList();
            foreach (var file in files)
            {
                try
                {
                    await torrentManager.PauseTorrent(file.VideoFileExtendedInfo.RutrackerId.ToString());

                    var moveResult = await fileManager.MoveFile(file);

                    if (moveResult.IsntExist)
                    {
                        db.Files.Remove(file);
                        await db.SaveChangesAsync();
                    }
                    else if (!string.IsNullOrEmpty(moveResult.DuplicatePath))
                    {
                        var dbFile = db.Files.FirstOrDefault(x => x.Path ==  moveResult.DuplicatePath);
                        if (dbFile != null)
                        {
                            db.Files.Remove(file);
                            await db.SaveChangesAsync();
                        }
                        else
                            File.Delete(moveResult.DuplicatePath);
                    }
                    else if (moveResult.HasBeenConverted)
                        await torrentManager.DeleteTorrent(file.VideoFileExtendedInfo.RutrackerId.ToString());
                    else if (moveResult.HasBeenMoved)
                        await MoveFileInRutracker(torrentManager, file);

                    if(moveResult.HasBeenMoved)
                        movedFiles++;
                }
                catch (Exception ex)
                {
                    NLog.LogManager.GetCurrentClassLogger().Error(ex);
                }
            }
        }

        private async Task MoveFileInRutracker(IRuTrackerUpdater torrentManager, DbFile file)
        {
            var fi = new FileInfo(file.Path);
            await torrentManager.MoveTorrent(file.VideoFileExtendedInfo.RutrackerId, fi.Directory.FullName);
        }
    }
}
