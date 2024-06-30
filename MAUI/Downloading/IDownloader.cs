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

namespace MAUI.Downloading
{
    class DownloaderMaui 
    {
        private readonly IHttpTransferManager _transferManager;
        private string _filePath;

        public event DownloadProgressChangedEventHandler? DownloadProgressChanged;
        public event AsyncCompletedEventHandler? DownloadFileCompleted;

        public DownloaderMaui(IHttpTransferManager transferManager)
        {
            _transferManager = transferManager;
        }

        private static int _counter = 111;

        public async Task StartDownload(string fileWriteTo, string url)
        {
            try
            {
                var fileId = _counter++.ToString();
                //var path = FileSystem.AppDataDirectory;
                //fileWriteTo = Path.Combine(path, fileId);

                //url = "https://file-examples.com/wp-content/storage/2017/04/file_example_MP4_1280_10MG.mp4";
                var task = await _transferManager.Queue(new HttpTransferRequest(fileId, url, false, fileWriteTo, true));

                var sub = _transferManager.WatchTransfer(fileId).Subscribe(
                    x =>
                    {
                    },
                    ex =>
                    {
                        this.DownloadFileCompleted?.Invoke(this, new AsyncCompletedEventArgs(ex, true, fileId));
                    },
                    () =>
                    {
                        this.DownloadFileCompleted?.Invoke(this, new AsyncCompletedEventArgs(null, false, fileId));
                    }
                );

                //var yourRequests = await _transferManager.GetTransfers();
                //await _transferManager.Queue(new HttpTransfeсяrRequest(fileWriteTo, url, false, fileWriteTo, true));

                //Thread.Sleep(10000);

                //var tasks = await _transferManager.GetTransfers();
            }
            catch (Exception)
            {
            }
        }
    }

    public class DownloaderBase 
    {
        public event DownloadProgressChangedEventHandler? DownloadProgressChanged;
        public event AsyncCompletedEventHandler? DownloadFileCompleted;

        public async Task StartDownload(string fileWriteTo, string url)
        {
            try
            {
                WebClient webClient = new WebClient();
                webClient.DownloadProgressChanged += new DownloadProgressChangedEventHandler(DownloadProgressCallback);
                webClient.DownloadFileCompleted += new AsyncCompletedEventHandler(DownloadCompletedCallback);
                webClient.DownloadFileAsync(new Uri(url), fileWriteTo);
            }
            catch (Exception ex)
            {
            }
        }
        private void DownloadProgressCallback(object sender, DownloadProgressChangedEventArgs e)
        {
            this.DownloadProgressChanged?.Invoke(this, e);
        }

        private void DownloadCompletedCallback(object? sender, AsyncCompletedEventArgs e)
        {
            this.DownloadFileCompleted?.Invoke(this, e);
        }

        static HttpClient Client = new HttpClient((new Xamarin.Android.Net.AndroidMessageHandler()));

        public static void UseCustomHttpClient(HttpClient client)
        {
            if (client is null)
                throw new ArgumentNullException($"The {nameof(client)} can't be null.");

            Client.Dispose();
            Client = null;
            Client = client;
        }
    }
}