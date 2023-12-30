using FileStore.Domain;
using FileStore.Domain.Models;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using static System.Net.Mime.MediaTypeNames;

namespace API.FilmDownload
{
    public class DownloadInfo
    {
        public string ChannelName { get; set; }
        public string ListName { get; set; }
        public bool IsList { get; set; }

        public Dictionary<string, VideoFile> Records { get; set; } = new Dictionary<string, VideoFile>();
    }

    public class DownloadTask
    {
        public DownloadTask(int messageId, string text)
        {
            OriginalMessageId = messageId;
            ParseMessageText(text);
        }

        public string Id { get; set; } = Guid.NewGuid().ToString();

        public int OriginalMessageId { get; set; }
        public int QuestionMessageId { get; set; }
        public string SeasonName { get; set; }
        public Uri Uri { get; set; }
        public bool WatchLater { get; internal set; }
        public DownloadType DownloadType { get; internal set; }

        private void ParseMessageText(string text)
        {
            var parts = text.Split(' ');
            if (parts.Length > 1)
                SeasonName = string.Join(" ", parts.Take(parts.Length - 1));

            var url = parts.Last();
            if (Uri.TryCreate(url, UriKind.Absolute, out var uri))
                Uri = uri;
        }

        internal string GetSeasonName(string channelName)
        {
            if (!string.IsNullOrEmpty(SeasonName))
                return SeasonName;

            return !WatchLater || DownloadType == DownloadType.Common ? channelName : $"{DownloadType}" ;
        }

        internal string GetSeriesName()
        {
            return WatchLater ? "На один раз" : DownloadType.ToString();
        }
    }

    public enum DownloadType
    {
        Youtube = 0,
        VK = 1,
        Common = 2,

    }
    public class DownloaderFabric
    {
        public static DownloaderBase CreateDownloader(DownloadTask task, AppConfig config)
        {
            var url = task.Uri?.ToString();

            if (url == null || url.Contains("rutracker.org"))
                return null;

            if (url.Contains("youtube") || url.Contains("youtu.be"))
                return new YoutubeDownloader(config);
            else if (url.Contains("vk.com"))
                return new VKDownloader(config);
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
        protected AppConfig _config;
        public abstract DownloadType DownloadType { get; }
        public abstract bool IsVideoPropertiesFilled { get;}

        public async Task<DownloadInfo> GetInfo(string url)
        {
            string rootDownloadFolder = Path.Combine(_config.RootDownloadFolder, DownloadType.ToString());

            if (IsPlaylist(url))
                return await GetPlaylistInfo(url, rootDownloadFolder);
            else
                return await GetVideoInfo(url, rootDownloadFolder);
        }

        public virtual async Task Download(string url, string path)
        {
            //$path = '{path.Replace(" ", "")}'
            var downloadUtilitiesScript = File.ReadAllText(@"Assets\downloadScript.txt");
            var downloadVideoScript = @$"
            $ytdlp = 'yt-dlp.exe'
            $cmd = '-f bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best --merge-output-format mp4 {url} -o {path}'
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
        }

        protected abstract bool IsPlaylist(string url);
        protected abstract Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder);
        protected abstract Task<DownloadInfo> GetVideoInfo(string url, string rootDownloadFolder);

    }
}
