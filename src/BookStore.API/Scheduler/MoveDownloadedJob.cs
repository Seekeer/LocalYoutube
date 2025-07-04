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
using System.IO;
using System.Threading.Tasks;
using API.Controllers;

namespace Infrastructure.Scheduler
{
    [DisallowConcurrentExecution]
    public class MoveDownloadedJob(IServiceProvider service, AppConfig appConfig) : JobBase
    {
        protected override async Task ExecuteAsync(IJobExecutionContext context)
        {
            await this.MoveFiles();
        }

        public async Task MoveFiles()
        {
            var db = service.GetService<VideoCatalogDbContext>();
            var fileManager = new FileManager(db, new FileManagerSettings(appConfig.RootDownloadFolder, appConfig.RootFolder,  true));
            var movedFiles = 0;
            var torrentManager = service.GetService<IRuTrackerUpdater>();

            var files = db.Files.Where(x => x.Path.Contains(appConfig.RootDownloadFolder) && !x.IsDownloading)
                .Include(x => x.VideoFileExtendedInfo).ToList().OrderBy(x => x.Duration);
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

            var diskFiles = Directory.EnumerateFiles(appConfig.RootDownloadFolder, "*.*", SearchOption.AllDirectories);
            foreach (var item in diskFiles)
            {
                try
                {
                    if (!item.EndsWith("#.f616.mp4") && !item.EndsWith("#.temp.mp4"))
                        continue;

                    var dbFile = db.Files.FirstOrDefault(x => x.Path == item);
                    if (dbFile != null)
                        continue;

                    File.Delete(item);

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
