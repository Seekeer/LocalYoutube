using Dtos;
using FileStore.Domain.Interfaces;
using FileStore.Infrastructure.Repositories;
using MAUI.ViewModels;
using Microsoft.Maui.Storage;
using Shiny;
using Shiny.Net.Http;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using MAUI.Services;
using System.Security.Policy;
using FileStore.Domain.Models;
using Infrastructure;

namespace MAUI.Downloading
{
    public partial class DownloadManager
    {
        public DownloadManager(IMAUIService videoFileRepository)
        {
            _videoFileRepository = videoFileRepository;
        }

        private readonly IMAUIService _videoFileRepository;

        internal async Task CheckDownloadedAsync(IEnumerable<VideoFileResultDtoDownloaded> dto)
        {
            foreach (var file in dto)
            {
                var dbFile = await _videoFileRepository.GetFileById(file.Id);
                if (FileDownloaded(dbFile))
                {
                    file.IsDownloaded = true;
                    file.Path = dbFile.Path;
                }
            }
        }

        internal async Task DeleteDownloaded(int fileId)
        {
            var file = await _videoFileRepository.GetFileById(fileId);

            if (string.IsNullOrEmpty(file?.Path))
                return;

            File.Delete(file.Path);
            await _videoFileRepository.UpdateFilePathAsync(fileId, null);
        }

        internal async Task StartDownloadAsync(IEnumerable<VideoFileResultDtoDownloaded> dtos)
        {
            foreach (var dto in dtos)
                await StartDownloadAsync(dto);
        }

        public async Task StartDownloadAsync(VideoFileResultDtoDownloaded fileDTO)
        {
            _videoFileRepository.AddFileIfNeeded(fileDTO);
            var file = await _videoFileRepository.GetFileById(fileDTO.Id);

            if (FileDownloaded(file))
                return;

            var name = fileDTO.Name.GetCorrectFileName();

            string path = GetFilePath(Guid.NewGuid().ToString());

            await DownloadFile(fileDTO, name, path);
        }

        public static string GetFilePath(string name)
        {
            var path = PlataformFolder();
            path = Path.Combine(path, name);
            return path;
        }

        private static bool FileDownloaded(VideoFile file)
        {
            return !string.IsNullOrEmpty(file?.Path) && File.Exists(file.Path);
        }

        private async Task DownloadFile(VideoFileResultDtoDownloaded fileDTO, string name, string path)
        {
            var url = HttpClientAuth.GetVideoUrlById(fileDTO.Id);
#if ANDROID
            await DownloadAndroid(fileDTO, name, path, url);
#else
            DownloadWindows(fileDTO, path, url);
#endif
        }

        private void DownloadWindows(VideoFileResultDtoDownloaded fileDTO, string path, string url)
        {
            WebClient webClient = new WebClient();
            //webClient.DownloadProgressChanged += new DownloadProgressChangedEventHandler(DownloadProgressCallback);
            webClient.DownloadFileCompleted += (_, __) => DownloadFinished(fileDTO, path);
            webClient.DownloadFileAsync(new Uri(url), path);
        }

        private async Task DownloadAndroid(VideoFileResultDtoDownloaded fileDTO, string name, string path, string url)
        {
            var manager = Application.Current.MainPage.Handler.MauiContext.Services.GetService<IHttpTransferManager>();
            var task = await manager.Queue(new HttpTransferRequest(name, url, false, path, true));
            var sub = manager.WatchTransfer(name).Subscribe(
                x =>
                {
                },
                ex =>
                {
                },
                () =>
                {
                    DownloadFinished(fileDTO, path);
                }
            );
        }

        private void DownloadFinished(VideoFileResultDtoDownloaded fileDTO, string path)
        {
            _videoFileRepository.UpdateFilePathAsync(fileDTO.Id, path);
            fileDTO.IsDownloaded = true;
        }

        private static string PlataformFolder()
        {
            return FileSystem.AppDataDirectory;
        }

    }
}