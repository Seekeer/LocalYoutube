using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Infrastructure
{
    public struct FileManagerSettings
    {
        public FileManagerSettings(string rootDownloadFolder, string rootFolder, bool convertFilesIfNeeded) : this()
        {
            FromFolder = rootDownloadFolder;
            ToFolder = rootFolder;
            ConvertFilesIfNeeded = convertFilesIfNeeded;
        }

        public long FileBufferLimit { get; } = (long)150 * 1024 * 1024 * 1024;
        public TimeSpan BuefferWaitTime { get; } = TimeSpan.FromMinutes(2);
        public string FromFolder { get; }
        public string ToFolder { get;  }
        public bool ConvertFilesIfNeeded { get; }
    }

    public class FileManager
    {
        public FileManager(VideoCatalogDbContext db, FileManagerSettings settings)
        {
            _settings = settings;
            _db = db;
        }

        public async Task<string> MoveFile(DbFile file)
        {
            try
            {
                var newPath = _MoveFilePhysically(file);
                if (newPath != null)
                {
                    NLog.LogManager.GetCurrentClassLogger().Info($"FileManager {file.Id} from {file.Path} to {newPath}");

                    file.Path = newPath;
                    _db.Update(file);
                    await _db.SaveChangesAsync();
                }

                return newPath;
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error($"FileManager", ex);
            }

            return null;
        }

        private string _MoveFilePhysically(DbFile file)
        {
            var finfo = new FileInfo(file.Path);

            if (!finfo.Exists)
                return null;

            ConvertIfNeeded(file);

            var newPath = file.Path.Replace(_settings.FromFolder, _settings.ToFolder);

            var newFInfo = new FileInfo(newPath);

            if (newFInfo.Exists)
                return newPath;

            WaitIfNeeded(finfo);

            var dir = newFInfo.Directory;
            if (!dir.Exists)
                Directory.CreateDirectory(dir.FullName);

            _bufferFileSize += finfo.Length;

            File.Move(file.Path, newPath);

            return newPath;
        }

        private void ConvertIfNeeded(DbFile file)
        {
            if (!_settings.ConvertFilesIfNeeded || !VideoHelper.ShouldConvert(file as VideoFile))
                return;

            var oldFile = file.Path;
            file.Path = VideoHelper.EncodeToMp4(file.Path, false);
            _db.Update(file);
            _db.SaveChanges();
            File.Delete(oldFile);
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

        private readonly FileManagerSettings _settings;
        private readonly VideoCatalogDbContext _db;
        private long _bufferFileSize;

    }
}
