using API.Resources;
using FileStore.Domain;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Repositories;
using Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using OpenQA.Selenium.DevTools.V126.CSS;
using Polly;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using TwoCaptcha.Exceptions;
using VkNet.Model;

namespace API.FilmDownload
{
    public class DownloadInfo : ChannelInfo
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
            else if (url.Contains("mishka-knizhka.ru"))
                return new MishkaDownloader(config);
            else
                return new CommonDownloader(config);
        }

        internal static bool CanDownload(DownloadTask task)
        {
            var downloader = CreateDownloader(task, null);

            return downloader != null;
        }
    }

    public abstract class DownloaderBase : IDisposable
    {
        protected DownloaderBase(AppConfig config) { 
            this._config = config;
        }

        protected AppConfig _config;
        protected bool _useProxy;
        public abstract DownloadType DownloadType { get; }
        public abstract bool IsVideoPropertiesFilled { get;}

        public async Task DownloadAndProcess(DownloadTask task, IServiceScopeFactory serviceScopeFactory,
            Action<Exception> error, Action<DbFile> success)
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
                    using (var fileService = scope.ServiceProvider.GetRequiredService<IExternalVideoMappingsService>())
                    {
                        UpdateInfoByTask(task, info);
                        if (!await fileService.FillFileFromSiteDownloadTask(record.Value, info, DownloadType, task.NumberInSeries))
                            continue;

                        var policy = Policy
                            .Handle<Exception>()
                            .WaitAndRetryAsync(3, retryAttempt => TimeSpan.FromSeconds(60));

                        await policy.ExecuteAsync(async () =>
                        {
                            record.Value.Path = await Download(record.Key, record.Value.Path);

                            if (!System.IO.File.Exists(record.Value.Path))
                            {
                                throw new NetworkException("Can't donwload file");
                            }

                            UpdateFileByTask(record.Value, task);
                            task.FileId = await fileService.DownloadFinishedAsync(record.Value, IsVideoPropertiesFilled);

                            success(record.Value);
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
                info.ChannelName = task.SeasonName;
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

        public virtual async Task<string> Download(string url, string path)
        {
            path = PrepareFilePath(path);

            //$path = '{path.Replace(" ", "")}'
            url = url.ClearEnd("&list=");
            var fInfo = new FileInfo(path);
            var fileName = fInfo.FullName.Replace(fInfo.Extension, "");

            var downloadUtilitiesScript = File.ReadAllText(@"Assets\downloadScript.txt");
            //var proxyStr = "";
            var proxyStr = !_useProxy ? "" : $"--proxy {ProxyManager.GetProxyString()}";
            var downloadVideoScript = @$"
            $ytdlp = 'yt-dlp.exe'
            $cmd = '-f ""bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"" {proxyStr} --fragment-retries 30 --write-info-json --merge-output-format mp4 {url} -o """"{fileName}""""' 
            Start-Process -FilePath $ytdlp -ArgumentList $cmd -Wait -WindowStyle Minimized
";
            //$cmd = '-f ""bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"" {proxyStr} --merge-output-format mp4 {url} --sponsorblock-remove sponsor --ffmpeg-location ./ffmpegytdlp -o """"{fileName}""""' 
            // add --verbose and run in cmd for debug.

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

        internal void UpdateFileByTask(DbFile value, DownloadTask task)
        {
            if (!string.IsNullOrEmpty(task.VideoName))
                value.Name = task.VideoName;

            value.VideoFileExtendedInfo.ExternalLink = task.Uri.ToString();

            if(!string.IsNullOrEmpty(task.CoverUrl))
                value.VideoFileExtendedInfo.SetCoverByUrl(task.CoverUrl);
        }

        public virtual void Dispose()
        {
        }
    }
}
