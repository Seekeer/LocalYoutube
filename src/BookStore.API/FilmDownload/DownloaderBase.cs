using FileStore.Domain;
using FileStore.Domain.Models;
using Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Polly;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace API.FilmDownload
{
    public class DownloadInfo
    {
        public string ChannelName { get; set; }
        public string ListName { get; set; }
        public bool IsList { get; set; }

        public Dictionary<string, VideoFile> Records { get; set; } = new Dictionary<string, VideoFile>();
    }

    public class TgDownloadTask: DownloadTask
    {
        public TgDownloadTask(int messageId, long fromId, string text)
        {
            OriginalMessageId = messageId;
            FromId = fromId;
            ParseMessageText(text);
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

        public int OriginalMessageId { get; set; }
        public long FromId { get; }
        public int QuestionMessageId { get; set; }
    }

    public class DownloadTask
    {
        public const string PARTS_SEPARATOR = "!!";

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

        internal string GetSeasonName(string channelName)
        {
            return SeasonName ?? channelName ?? $"{DownloadType}";
        }

        internal string GetSeriesName()
        {
            return SeriesName ?? DownloadType.ToString();
        }
    }

    public enum DownloadType
    {
        Youtube = 0,
        VK = 1,
        Common = 2,
        Rossaprimavera = 3,
    }

    public class DownloaderFabric
    {
        public static DownloaderBase CreateDownloader(DownloadTask task, AppConfig config)
        {
            return CreateDownloader(task.Uri?.ToString(), config);
        }
        public static DownloaderBase CreateDownloader(string url, AppConfig config)
        {
            if (url == null || url.Contains("rutracker.org"))
                return null;

            if (url.Contains("youtube") || url.Contains("youtu.be"))
                return new YoutubeDownloader(config);
            else if (url.Contains("vk.com"))
                return new VKDownloader(config);
            else if (url.Contains("rossaprimavera"))
                return new RossaDownloader(config);
            else
                return new CommonDownloader(config);
        }

        internal static bool CanDownload(DownloadTask task)
        {
            var downloader = CreateDownloader(task, null);

            return downloader != null;
        }
    }

    public abstract class DownloaderBase
    {
        protected DownloaderBase(AppConfig config) { 
            this._config = config;
        }

        protected AppConfig _config;
        public abstract DownloadType DownloadType { get; }
        public abstract bool IsVideoPropertiesFilled { get;}

        public async Task DownloadAndProcess(DownloadTask task, IServiceScopeFactory serviceScopeFactory,
            Action<Exception> error, Action<VideoFile> success)
        {
            var info = await GetInfo(task.Uri.ToString());

            foreach (var record in info.Records)
            {
                try
                {
                    var scope = serviceScopeFactory.CreateScope();
                    using (var fileService = scope.ServiceProvider.GetRequiredService<DbUpdateManager>())
                    {
                        fileService.AddFromSiteDownload(record.Value, task.GetSeriesName(), task.GetSeasonName(info.ChannelName), task.NumberInSeries);

                        var policy = Policy
                            .Handle<Exception>()
                            .WaitAndRetry(20, retryAttempt => TimeSpan.FromSeconds(10));

                        await policy.Execute(async () =>
                        {
                            record.Value.Path = await Download(record.Key, record.Value.Path);

                            if (!System.IO.File.Exists(record.Value.Path))
                            {
                                throw new ArgumentException();
                            }

                            UpdateFileByTask(record.Value, task);
                            task.FileId = await fileService.DownloadFinishedAsync(record.Value, IsVideoPropertiesFilled);

                            success(record.Value);
                        });
                    }
                }
                catch (Exception ex)
                {
                    error(ex);
                }
            }
        }

        public async Task<DownloadInfo> GetInfo(string url)
        {
            string rootDownloadFolder = Path.Combine(_config.RootDownloadFolder, DownloadType.ToString());

            if (IsPlaylist(url))
                return await GetPlaylistInfo(url, rootDownloadFolder);
            else
                return await GetVideoInfo(url, rootDownloadFolder);
        }

        public virtual async Task<string> Download(string url, string path)
        {
            path = PrepareFilePath(path);

            //$path = '{path.Replace(" ", "")}'
            url = url.ClearEnd("&list=");
            var fInfo = new FileInfo(path);
            var fileName = fInfo.FullName.Replace(fInfo.Extension, "");

            var downloadUtilitiesScript = File.ReadAllText(@"Assets\downloadScript.txt");
            var downloadVideoScript = @$"
            $ytdlp = 'yt-dlp.exe'
            $cmd = '-f ""bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"" --merge-output-format mp4 {url} -o """"{fileName}""""'
            Start-Process -FilePath $ytdlp -ArgumentList $cmd -Wait 
";

            var finalScript = downloadUtilitiesScript + downloadVideoScript;

            var processStartInfo = new ProcessStartInfo();
            processStartInfo.FileName = "powershell.exe";
            processStartInfo.Arguments = $"-Command \"{finalScript}\"";
            processStartInfo.UseShellExecute = false;
            processStartInfo.RedirectStandardOutput = true;
            processStartInfo.WorkingDirectory = Path.Combine(Directory.GetCurrentDirectory(), "Assets");
            processStartInfo.UseShellExecute = false; // causes consoles to share window 

            using var process = new Process();
            process.StartInfo = processStartInfo;
            process.Start();
            await process.WaitForExitAsync();
            string output = process.StandardOutput.ReadToEnd();

            if (File.Exists(fileName))
                File.Move(fileName, path);
            else
            {
                fileName = fileName + "#";
                if (File.Exists(fileName))
                {
                    if (File.Exists(path))
                        File.Delete(path);
                    
                    File.Move(fileName, path);
                }
                else if (File.Exists(fileName + ".mp4"))
                {
                    if (File.Exists(path))
                        File.Delete(fileName + ".mp4");
                    else 
                        File.Move(fileName + ".mp4", path);
                }
            }
            return path;
        }

        protected abstract bool IsPlaylist(string url);
        protected abstract Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder);
        protected abstract Task<DownloadInfo> GetVideoInfo(string url, string rootDownloadFolder);

        private string PrepareFilePath(string path)
        {
            return path.Replace(" ", "")
                // ' is breaking powershell script
                .Replace("'", "");
        }

        internal void UpdateFileByTask(VideoFile value, DownloadTask task)
        {
            if (!string.IsNullOrEmpty(task.VideoName))
                value.Name = task.VideoName;

            value.VideoFileExtendedInfo.ExternalLink = task.Uri.ToString();

            if(!string.IsNullOrEmpty(task.CoverUrl))
                value.VideoFileExtendedInfo.SetCoverByUrl(task.CoverUrl);
        }
    }
}
