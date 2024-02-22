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

namespace Infrastructure.Scheduler
{
    [DisallowConcurrentExecution]
    public class MoveDownloadedJob : NightJob
    {
        private readonly IServiceProvider _service;
        private readonly AppConfig _appConfig;

        private readonly long FILE_BUFFER_LIMIT = (long)15 * 1024 * 1024 * 1024;
        private readonly TimeSpan BufferWaitTime = TimeSpan.FromMinutes(2);
        private long _bufferFileSize;

        public MoveDownloadedJob(IServiceProvider service, AppConfig appConfig)
        {
            _service = service;
            _appConfig = appConfig;
        }

        protected override async Task Execute()
        {
            var counter = 0;
            var db = _service.GetService<VideoCatalogDbContext>();
            var torrentManager = _service.GetService<IRuTrackerUpdater>();

            //var files = db.VideoFiles.Where(x => x.Path.Contains(@"D:\VideoServer\")).Include(x => x.VideoFileExtendedInfo).ToList();
            //var rutrackerIds = files.GroupBy(x => x.VideoFileExtendedInfo.RutrackerId);
            //foreach (var item in rutrackerIds)
            //{
            //    await MoveFileInRutracker(db, torrentManager, item.First());
            //}

            var files = db.Files.Where(x => x.Path.Contains(_appConfig.RootDownloadFolder)).OrderBy(x => x.Duration).ToList();
            foreach (var file in files)
            {
                try
                {
                    var newPath = CopyFile(file);
                    if (newPath != null)
                    {
                        NLog.LogManager.GetCurrentClassLogger().Info($"MoveDownloadedJob {file.Id} from {file.Path} to {newPath}");

                        file.Path = newPath;
                        db.Update(file);
                        await db.SaveChangesAsync();

                        await MoveFileInRutracker(db, torrentManager, file);
                    }

                    counter++;
                }
                catch (Exception ex)
                {
                    NLog.LogManager.GetCurrentClassLogger().Error($"MoveDownloadedJob", ex);
                }
            }
        }

        private async Task MoveFileInRutracker(VideoCatalogDbContext db, IRuTrackerUpdater torrentManager, DbFile file)
        {
            var videoInfo = db.FilesInfo.FirstOrDefault(x => x.DbFile == file);

            if(videoInfo != null)
            {
                var fi = new FileInfo(file.Path);
                await torrentManager.MoveTorrent(videoInfo.RutrackerId, fi.DirectoryName);
            }
        }

        private string CopyFile(DbFile file)
        {
            var path = file.Path;

            var finfo = new FileInfo(path);

            if (!finfo.Exists)
                return null;

            var newPath = path.Replace(_appConfig.RootDownloadFolder, _appConfig.RootFolder);

            var newFInfo = new FileInfo(newPath);

            if (newFInfo.Exists)
                return newPath;

            WaitIfNeeded(finfo);

            var dir = newFInfo.Directory;

            if (!dir.Exists)
                Directory.CreateDirectory(dir.FullName);

            _bufferFileSize += finfo.Length;

            return Move(file, newPath);
        }

        private string Move(DbFile file, string newPath)
        {
            if (VideoHelper.ShouldConvert(file as VideoFile))
                newPath = VideoHelper.EncodeToMp4(file.Path, false, newPath);
            else
                File.Move(file.Path, newPath);

            return newPath;
        }

        private void WaitIfNeeded(FileInfo finfo)
        {
            if (!OverLimit(finfo))
                return;

            Thread.Sleep(BufferWaitTime);
            _bufferFileSize = 0;
        }

        private bool OverLimit(FileInfo finfo)
        {
            return _bufferFileSize + finfo.Length > FILE_BUFFER_LIMIT;
        }
    }
}
