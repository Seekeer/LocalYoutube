using API.Resources;
using BookStore.Domain.Interfaces;
using FileStore.Domain;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Domain.Services;
using FileStore.Infrastructure.Repositories;
using Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.DependencyInjection;
using OpenQA.Selenium.DevTools.V126.CSS;
using Polly;
using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using TwoCaptcha.Exceptions;
using VkNet.Model;

namespace API.FilmDownload
{
    public record DownloadInfo : ChannelInfo
    {
        public string ListName { get; set; }
        public bool IsList { get; set; }

        public Dictionary<string, DbFile> Records { get; set; } = new Dictionary<string, DbFile>();
    }

    public class TgDownloadTask: DownloadTask
    {
        public TgDownloadTask(int messageId, long fromId, string text)
        {
            OriginalMessageId = messageId;
            FromId = fromId;
            ParseMessageText(text);
            OriginalLine = text;
        }

        private void ParseMessageText(string text)
        {
            var parts = text.Split(PARTS_SEPARATOR, StringSplitOptions.RemoveEmptyEntries);

            var url = parts.Last();
            if (Uri.TryCreate(url, UriKind.Absolute, out var uri))
                Uri = uri;

            if (parts.Length > 1)
                VideoName = parts[0];

            if (parts.Length > 2)
                CoverUrl = parts[1];
        }

        internal static bool IsDownloadCommand(IEnumerable<string> lines)
        {
            return lines.First().StartsWith(DownloadTask.PARTS_SEPARATOR) || lines.First().StartsWith(DownloadTask.SUBSCRIBE_TO_CHANNEL);
        }

        // Subscribe
        // ##!
        // https://www.youtube.com/watch?v=x2CRZaN2xgM
        // !!СЕ!!Выступления
        // Кургинян: либо Россия будет определять судьбу человечества, либо ее не будет!!https://rossaprimavera.ru/static/files/b7b43b3d3b12.jpg!!https://rossaprimavera.ru/video/7e53f655
        internal static List<TgDownloadTask> ParseTasks(Telegram.Bot.Types.Message message, IEnumerable<string> lines)
        {
            var commands = lines.First().Split(DownloadTask.PARTS_SEPARATOR, StringSplitOptions.RemoveEmptyEntries);

            var errorLines = new List<string>();
            var result = new List<TgDownloadTask>();
            foreach (var line in lines.Skip(1).ToList())
            {
                var task = new TgDownloadTask(message.MessageId, message.From.Id, line);
                if (!string.IsNullOrEmpty(commands[0])&& !commands[0].StartsWith(SUBSCRIBE_TO_CHANNEL))
                    task.SeriesName = commands[0];

                if (commands.Length > 1 && !string.IsNullOrEmpty(commands[1]) && !commands[1].StartsWith(SUBSCRIBE_TO_CHANNEL))
                    task.SeasonName = commands[1];

                if (commands.Last().StartsWith(SUBSCRIBE_TO_CHANNEL))
                {
                    task.SubscribeToChannel = true;
                    task.FullDownload = commands.Last().EndsWith('!');
                }

                result.Add(task);
            }

            return result;
        }

        public int OriginalMessageId { get; set; }
        public long FromId { get; }
        public int QuestionMessageId { get; set; }
        public string OriginalLine { get; internal set; }
    }

    public class DownloadTask
    {
        public const string PARTS_SEPARATOR = "!!";
        public const string SUBSCRIBE_TO_CHANNEL = "##";

        public DownloadTask(string url, string? coverUrl)
        {
            Uri = new Uri(url);
            CoverUrl = coverUrl;
        }

        protected DownloadTask() { }

        public string Id { get; set; } = Guid.NewGuid().ToString();

        public int FileId { get; set; }
        public string SeasonName { get; set; }
        public string SeriesName { get; internal set; }
        public int NumberInSeries { get; internal set; }
        public string VideoName { get; set; }
        public string CoverUrl { get; protected set; }
        public Uri Uri { get; set; }
        public DownloadType DownloadType { get; internal set; }
        public bool SubscribeToChannel { get; internal set; }
        public bool FullDownload { get; protected set; }
        public bool IsAutoTask { get; internal set; }
    }

    public class DownloaderFabric
    {
        public static DownloaderBase CreateDownloader(DownloadTask task, AppConfig config, IDownloadServiceFactory downloadServiceFactory)
        {
            return CreateDownloader(task.Uri?.ToString(), config, downloadServiceFactory);
        }
        
        public static DownloaderBase CreateDownloader(string url, AppConfig config, IDownloadServiceFactory downloadServiceFactory)
        {
            if (url == null || url.Contains("rutracker.org"))
                return null;

            var downloadService = downloadServiceFactory.CreateDownloadService(config);

            if (url.Contains("youtube") || url.Contains("youtu.be"))
                return new YoutubeDownloader(config, false, downloadService);
            else if (url.Contains("vk.com") || url.Contains("vkvideo.ru"))
                return new VKDownloader(config, downloadService);
            else if (url.Contains("rossaprimavera"))
                return new RossaDownloader(config, downloadService);
            else if (url.Contains("mishka-knizhka.ru"))
                return new MishkaDownloader(config, downloadService);
            else
                return new CommonDownloader(config, downloadService);
        }

        // Backward compatibility method - deprecated but maintained for existing code
        [System.Obsolete("Use CreateDownloader with IDownloadServiceFactory instead")]
        public static DownloaderBase CreateDownloader(DownloadTask task, AppConfig config, IDownloadService downloadService)
        {
            return CreateDownloader(task.Uri?.ToString(), config, downloadService);
        }
        
        [System.Obsolete("Use CreateDownloader with IDownloadServiceFactory instead")]
        public static DownloaderBase CreateDownloader(string url, AppConfig config, IDownloadService downloadService)
        {
            if (url == null || url.Contains("rutracker.org"))
                return null;

            if (url.Contains("youtube") || url.Contains("youtu.be"))
                return new YoutubeDownloader(config, false, downloadService);
            else if (url.Contains("vk.com") || url.Contains("vkvideo.ru"))
                return new VKDownloader(config, downloadService);
            else if (url.Contains("rossaprimavera"))
                return new RossaDownloader(config, downloadService);
            else if (url.Contains("mishka-knizhka.ru"))
                return new MishkaDownloader(config, downloadService);
            else
                return new CommonDownloader(config, downloadService);
        }

        public static bool CanDownload(DownloadTask task, AppConfig _config, IDownloadServiceFactory downloadServiceFactory)
        {
            var downloader = CreateDownloader(task, _config, downloadServiceFactory);
            return downloader != null;
        }

        // Backward compatibility method - deprecated but maintained for existing code
        [System.Obsolete("Use CanDownload with IDownloadServiceFactory instead")]
        public static bool CanDownload(DownloadTask task, AppConfig _config, IDownloadService downloadService)
        {
            var downloader = CreateDownloader(task, _config, downloadService);
            return downloader != null;
        }
    }

    public class TestEx : DbException
    {

    }
    public abstract class DownloaderBase : IDisposable
    {
        protected DownloaderBase(AppConfig config, IDownloadService downloadService) { 
            this._config = config;
            this._downloadService = downloadService;
        }

        protected AppConfig _config;
        protected IDownloadService _downloadService;
        private static int _errorsCount;

        public abstract DownloadType DownloadType { get; }
        public abstract bool IsVideoPropertiesFilled { get;}

        public async Task DownloadAndProcess(DownloadTask task, IServiceScopeFactory serviceScopeFactory,
            Action<Exception> error, Action<bool, DbFile> success)
        {
            var info = await GetInfo(task.Uri.ToString());

            foreach (var record in info.Records)
            {
                try
                {
                    if (record.Value.Duration < TimeSpan.FromMinutes(1) && task.IsAutoTask)
                    {
                        NLog.LogManager.GetCurrentClassLogger().Info($"Got shorts {record.Key} in auto mode. Skipping it.");
                        continue;
                    }

                    var scope = serviceScopeFactory.CreateScope();
                    using (var dbFileService = scope.ServiceProvider.GetRequiredService<IDbFileService>())
                    using (var fileService = scope.ServiceProvider.GetRequiredService<IExternalVideoMappingsService>())
                    {
                        UpdateInfoByTask(task, info);
                        if (!await fileService.FillFileFromSiteDownloadTask(record.Key, record.Value, info, DownloadType, task.NumberInSeries))
                        {
                            success(false, record.Value);
                            continue;
                        }

                        var policy = Policy
                            .Handle<Exception>()
                            .WaitAndRetryAsync(3, retryAttempt => TimeSpan.FromSeconds(60));

                        await policy.ExecuteAsync(async () =>
                        {
                            record.Value.Path = await _downloadService.Download(record.Key, record.Value.Path);

                            if (!System.IO.File.Exists(record.Value.Path))
                            {
                                if(_errorsCount++ > 5)
                                {
                                    _errorsCount = 0;
                                    File.Delete(Path.Combine("Assets", "yt-dlp.exe"));
                                }
                                throw new NetworkException("Can't download file");
                            }

                            UpdateFileByTask(record.Value, task);
                            task.FileId = await fileService.DownloadFinishedAsync(record.Value, IsVideoPropertiesFilled);

                            success(true , record.Value);
                        });
                    }
                }
                catch (Exception ex)
                {
                    NLog.LogManager.GetCurrentClassLogger().Error($"DownloaderBase Error: {ex} message: {ex.Message}");
                    error(ex);
                }
            }

            this.Dispose();
        }

        private void UpdateInfoByTask(DownloadTask task, ChannelInfo info)
        {
            if (string.IsNullOrEmpty(task.SeasonName) && task.SeriesName != null)
                throw new ArgumentException();

            if(!task.SubscribeToChannel)
            {
                info.ChannelId = null;
            }
            if (task.FullDownload)
                info.FullDownload = true;

            if (task.SeasonName != null)
            {
                info.SeasonName = task.SeasonName;
                info.SeriesName = DownloadType.ToString();
            }

            if(task.SeriesName != null) 
                info.SeriesName = task.SeriesName;

            if(string.IsNullOrEmpty(info.SeriesName))
                info.SeriesName = DownloadType.ToString();
        }

        protected async Task<DownloadInfo> GetInfo(string url)
        {
            string rootDownloadFolder = Path.Combine(_config.RootDownloadFolder, DownloadType.ToString());

            if (IsPlaylist(url))
                return await GetPlaylistInfo(url, rootDownloadFolder);
            else
                return await GetVideoInfo(url, rootDownloadFolder);
        }



        protected abstract bool IsPlaylist(string url);
        protected abstract Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder);
        protected abstract Task<DownloadInfo> GetVideoInfo(string url, string rootDownloadFolder);

        internal void UpdateFileByTask(DbFile value, DownloadTask task)
        {
            if (!string.IsNullOrEmpty(task.VideoName))
                value.Name = task.VideoName;

            value.VideoFileExtendedInfo.ExternalLink = task.Uri.ToString();

            if(!string.IsNullOrEmpty(task.CoverUrl))
                value.SetCoverByUrl(task.CoverUrl);
        }

        public virtual void Dispose()
        {
        }
    }
}
