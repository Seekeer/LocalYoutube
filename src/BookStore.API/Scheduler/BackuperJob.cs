﻿using FileStore.Domain;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using FileStore.Infrastructure.Repositories;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Identity.Client;
using Quartz;
using Quartz.Impl;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using YandexDisk.Client.Clients;
using YandexDisk.Client.Http;

namespace Infrastructure.Scheduler
{
    public  struct UploadFile
    {
        public int Id { get; set; }
        public string Path { get; set; }
    }

    [DisallowConcurrentExecution]
    public class BackuperJob : JobBase
    {
        private readonly IServiceProvider _service;
        private readonly YandexDisc _client;
        private readonly AppConfig _config;

        public BackuperJob(IServiceProvider service, AppConfig appConfig) 
        {
            _service = service;
            _client = new YandexDisc(appConfig);
            _config = appConfig;
        }

        protected override async Task ExecuteAsync(IJobExecutionContext context)
        {
            NLog.LogManager.GetCurrentClassLogger().Debug($"BackuperJob");

            var stack = new ConcurrentBag<UploadFile>();

            using (var fileRepo = GetFileRepo())
            {
                var nonBackupedFiles = await fileRepo.SearchAsync(x => 
                    !x.IsBackedup && !x.NeedToDelete && !x.IsDownloading && x.Type != VideoType.ExternalVideo);
                nonBackupedFiles.ToList().ForEach(x => stack.Add(new UploadFile { Id = x.Id, Path = x.Path }));
            }

            foreach (var item in stack.ToList())
            //Parallel.For(0, _config.YD_Upload_Threads_Count, new ParallelOptions(), async i =>
            {
                //do
                //{
                if (!stack.TryTake(out var file))
                    return;
                await UploadAndSaveStatus(file);

            }
                //} while (true);
            //);

        }

        private async Task UploadAndSaveStatus(UploadFile file)
        {
            try
            {
                if (await _client.UploadFile(file.Path))
                {
                    var factory = new VideoCatalogContextFactory();
                    using (var db = factory.CreateDbContext(null))
                    {
                        var dbFile = db.Files.FirstOrDefault(x => x.Id == file.Id);
                        dbFile.IsBackedup = true;
                        await db.SaveChangesAsync();
                    }
                }
            }
            catch (Exception)
            {
            }
        }

        private IVideoFileRepository GetFileRepo()
        {
            return _service.CreateScope().ServiceProvider.GetService<IVideoFileRepository>();
        }
    }

    public class YandexDisc
    {
        public YandexDisc(AppConfig appConfig)
        {
            this.appConfig = appConfig;
            _token = appConfig.YandexToken;
        }

        public async Task<bool> UploadFile(string filepath)
        {
            if (!File.Exists(filepath))
                return false;

            long length = new System.IO.FileInfo(filepath).Length;

            if (length > (long)4 * 1024 * 1024 * 1024)
                return false;

            return await UploadToDirectory(filepath, GetFolderName(filepath));
        }

        private  string GetFolderName(string filepath)
        {
            var directory = new DirectoryInfo(filepath);
            var path = @"Backup/LocalTube" + directory.Parent.FullName.Replace(appConfig.RootFolder, "");
            return path.Replace(@"\", @"/");
        }

        public async Task<bool> UploadToDirectory(string filepath, string folderName)
        {
            NLog.LogManager.GetCurrentClassLogger().Warn($"Trying to upload{filepath}");

            var api = new DiskHttpApi(_token);

            string path = GetDiskFilepath(filepath, folderName);

            try
            {
                using (var fs = new FileStream(filepath, FileMode.Open))
                {
                    try
                    {
                        await api.Files.UploadFileAsync(path, false, fs, CancellationToken.None);

                    }
                    catch (YandexDisk.Client.YandexApiException ex)
                    {
                        if (ex.Message.Contains("doesn't exists"))
                        {
                            var folders = folderName.Split(@"/");
                            var folderPath = "";
                            foreach (var pathF in folders)
                            {
                                folderPath = $"{folderPath}/{pathF}";
                                try
                                {
                                    await api.Commands.CreateDictionaryAsync(folderPath);
                                }
                                catch (Exception)
                                {
                                }
                            }

                            await api.Files.UploadFileAsync(path, false, fs, CancellationToken.None);
                        }
                        else if (ex.Message.Contains("already exists"))
                            return true;
                        else
                            return false;
                    }

                    NLog.LogManager.GetCurrentClassLogger().Warn($"Uploaded");
                    return true;
                }
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex, $"Not uploaded");
                return false;
            }

        }

        private static string GetDiskFilepath(string filepath, string folderName)
        {
            var fileName = Path.GetFileName(filepath);
            var folderPath = !string.IsNullOrEmpty(folderName) ? '/' + folderName + "/" : "/";
            return folderPath + (fileName);
        }

        public async Task Download(string finaleFilePath, string filepath)
        {
            var api = new DiskHttpApi(_token);

            var path = (@"1234.avi");

            Task.Factory.StartNew(() =>
            {
                api.Files.DownloadFileAsync(path, finaleFilePath);
                //await api.Files.DownloadFileAsync(path, finaleFilePath);
            }, TaskCreationOptions.LongRunning);
        }

        #region Private members

        private readonly string _token;
        private AppConfig appConfig;

        #endregion
    }
}
