using FileStore.Domain;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Runtime;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Infrastructure
{
    public class FileManagerSettings
    {
        public FileManagerSettings(AppConfig config) 
        {
            Config = config;
            FromFolder = config.RootDownloadFolder;
            ToFolder = config.RootFolder;
        }

        public FileManagerSettings(string rootDownloadFolder, string rootFolder, bool convertFilesIfNeeded)
        {
            FromFolder = rootDownloadFolder;
            ToFolder = rootFolder;
            ConvertFilesIfNeeded = convertFilesIfNeeded;
        }

        public long FileBufferLimit { get; } = (long)150 * 1024 * 1024 * 1024;
        public TimeSpan BuefferWaitTime { get; } = TimeSpan.FromMinutes(2);
        public AppConfig Config { get; }
        public string FromFolder { get; }
        public string ToFolder { get;  }
        public bool ConvertFilesIfNeeded { get; }
    }

    public class MoveResult
    {
        public string NewPath { get; set; }
        public bool HasBeenConverted { get; set; }
        public bool HasBeenMoved { get
            { return !string.IsNullOrEmpty(NewPath); }
        }
    }

    public class FileManager
    {
        public FileManager(VideoCatalogDbContext db, FileManagerSettings settings)
        {
            _helper = new VideoHelper(settings);
            _settings = settings;
            _db = db;
        }

        public MoveResult MoveFileSync()
        {
            try
            {
                throw new ArgumentException();
            }
            catch (Exception ex)
            {
                //StackTrace st = new StackTrace(true);
                //Console.WriteLine(ex.StackTrace);
                //Console.WriteLine("....");
                //Console.WriteLine(st);

                //NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }

            return new MoveResult { };
        }


        public async Task<MoveResult> MoveFile(DbFile file)
        {
            try
            {
                var moveResult = _MoveFilePhysically(file);
                if (moveResult.HasBeenMoved)
                {
                    //NLog.LogManager.GetCurrentClassLogger().Info($"FileManager {file.Id} from {file.Path} to {moveResult.NewPath}");

                    file.Path = moveResult.NewPath;
                    _db.Update(file);
                    await _db.SaveChangesAsync();
                }

                return moveResult;
            }
            catch (Exception ex)
            {
                //NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }

            return new MoveResult { };
        }

        public string ZipFiles(IEnumerable<DbFile> files)
        {
            var filePath = Path.Combine(_settings.Config.RootDownloadFolder, "Upload");
            if (!Directory.Exists(filePath))
                Directory.CreateDirectory(filePath);

            filePath = Path.Combine(filePath, $"{Guid.NewGuid().ToString()}.zip");

            using (var zipFile = System.IO.File.Create(filePath))
            {
                using (var zipArchive = new ZipArchive(zipFile, ZipArchiveMode.Create, true))
                {
                    foreach (var file in files)
                    {
                        var finfo = new FileInfo(file.Path);
                        zipArchive.CreateEntryFromFile(file.Path, finfo.Name);
                    }
                }
            }

            return filePath;
        }

        private MoveResult _MoveFilePhysically(DbFile file)
        {
            var result = new MoveResult();

            var finfo = new FileInfo(file.Path);

            if (!finfo.Exists)
                return result;

            result.HasBeenConverted = ConvertIfNeeded(file);

            var newPath = file.Path.Replace(_settings.FromFolder, _settings.ToFolder);

            var newFInfo = new FileInfo(newPath);

            if (newFInfo.Exists)
                return result;

            WaitIfNeeded(finfo);

            var dir = newFInfo.Directory;
            if (!dir.Exists)
                Directory.CreateDirectory(dir.FullName);

            _bufferFileSize += finfo.Length;

            File.Move(file.Path, newPath);

            result.NewPath = newPath;
            return result;
        }

        private bool ConvertIfNeeded(DbFile file)
        {
            if (!_settings.ConvertFilesIfNeeded || !VideoHelper.ShouldConvert(file as VideoFile))
                return false;

            var oldFile = file.Path;
            file.Path = _helper.EncodeToMp4(file.Path, false);
            _db.Update(file);
            _db.SaveChanges();
            File.Delete(oldFile);
            return true;
        }

        private void WaitIfNeeded(FileInfo finfo)
        {
            if (!OverLimit(finfo))
                return;

            Thread.Sleep(_settings.BuefferWaitTime);
            _bufferFileSize = 0;
        }

        private bool OverLimit(FileInfo finfo)
        {
            return _bufferFileSize + finfo.Length > _settings.FileBufferLimit;
        }

        private readonly VideoHelper _helper;
        private readonly FileManagerSettings _settings;
        private readonly VideoCatalogDbContext _db;
        private long _bufferFileSize;

    }
}
