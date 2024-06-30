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

namespace MAUI.Downloading
{
    public partial class DownloadManager
    {
        public DownloadManager(IMAUIService videoFileRepository)
        {
            _videoFileRepository = videoFileRepository;
        }

        private readonly IMAUIService _videoFileRepository;

        internal async Task CheckDownloaded(IEnumerable<VideoFileResultDtoDownloaded> dto)
        {
            foreach (var file in dto)
            {
                var dbFile = await _videoFileRepository.GetFileById(file.Id);
                if (!string.IsNullOrEmpty(dbFile?.Path))
                    file.IsDownloaded = true;
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

        public async Task<string> DownloadAsync(VideoFileResultDtoDownloaded fileDTO)
        {
            _videoFileRepository.AddFileIfNeeded(fileDTO);
            var file = await _videoFileRepository.GetFileById(fileDTO.Id);

            if (!string.IsNullOrEmpty(file.Path))
                return file.Path;

            var name = fileDTO.Id.ToString();

            var path = PlataformFolder();
            name = Path.Combine(path, name);

            var downloader = CreateDownloader();
            await downloader.StartDownload(name, HttpClientAuth.GetVideoUrlById(fileDTO.Id));
            downloader.DownloadFileCompleted += (_, __) =>
            {
                if (__.Cancelled || __.Error != null)
                    return;
                else
                {
                    _videoFileRepository.UpdateFilePathAsync(fileDTO.Id, name);
                    fileDTO.IsDownloaded = true;
                };
            };
            
            return name;
        }

        private static IDownloader CreateDownloader()
        {
            var manager = Application.Current.MainPage.Handler.MauiContext.Services.GetService<IHttpTransferManager>();

            return new DownloaderMaui(manager);

            //return new DownloaderBase();
        }

        private static string PlataformFolder()
        {
            return FileSystem.AppDataDirectory;
            //#if ANDROID
            //            IWindowManager windowManager = Android.App.Application.Context.GetSystemService(Context.WindowService).JavaCast<IWindowManager>();
            //            SurfaceOrientation orientation = windowManager.DefaultDisplay.Rotation;
            //            bool isLandscape = orientation == SurfaceOrientation.Rotation90 || orientation == SurfaceOrientation.Rotation270;
            //            return isLandscape ? DeviceOrientation.Landscape : DeviceOrientation.Portrait;
            //#else
            //            return "";
            //#endif
        }
    }
}