﻿using FileStore.Domain;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
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
    public class BackuperJob : IJob
    {
        private readonly IServiceProvider _service;
        private readonly YandexDisc _client;
        private readonly AppConfig _config;

        public BackuperJob(IServiceProvider service, AppConfig appConfig) 
        {
            _service = service;
            _client = new YandexDisc(appConfig.YandexToken);
            _config = appConfig;
        }

        public async Task Execute(IJobExecutionContext context)
        {
#if DEBUG
            return;
#endif
            var stack = new ConcurrentBag<UploadFile>();

            using (var fileRepo = GetFileRepo())
            {
                var nonBackupedFiles = await fileRepo.Search(x => !x.IsBackedup);
                nonBackupedFiles.ToList().ForEach(x => stack.Add(new UploadFile { Id = x.Id, Path = x.Path }));
            }

            Parallel.For(0, _config.YD_Upload_Threads_Count, new ParallelOptions(), async i =>
            {
                do
                {
                    if ( !stack.TryTake(out var file))
                        return;
                    await UploadAndSaveStatus(file);

                } while (true);
            }
            );

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
                    //using (var fileRepo = GetFileRepo())
                    //{
                    //var dbFile = await fileRepo.GetById(file.Id);
                    //dbFile.IsBackedup = true;
                    //await fileRepo.Update(dbFile);
                    //}
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
        public YandexDisc(string token)
        {
            _token = token;
        }

        public async Task<bool> UploadFile(string filepath)
        {
            if (!File.Exists(filepath))
                return false;

            return await UploadToDirectory(filepath, GetFolderName(filepath));
        }

        private  string GetFolderName(string filepath)
        {
            var directory = new DirectoryInfo(filepath);
            var path = @"Backup/LocalTube/" + directory.Parent.FullName.Replace(@"F:\", "");
            return path.Replace(@"\", @"/");
        }

        public async Task<bool> UploadToDirectory(string filepath, string folderName)
        {
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
                            try
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
                            }
                            catch (System.Exception)
                            {
                            }

                            await api.Files.UploadFileAsync(path, false, fs, CancellationToken.None);
                        }
                    }

                    return true;
                }
            }
            catch (Exception ex)
            {
                return false;
            }

        }

        private static string GetDiskFilepath(string filepath, string folderName)
        {
            var fileName = Path.GetFileName(filepath);
            var folderPath = !string.IsNullOrEmpty(folderName) ? '/' + folderName + "/" : "/";
            return folderPath + (fileName);
        }

        #region Private members

        private readonly string _token;

        #endregion
    }
}