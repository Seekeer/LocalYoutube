using FileStore.Domain;
using FileStore.Domain.Models;
using System;
using System.Collections.Generic;
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

    public class DownloadTask
    {
        private string _name;
        private string _url;

        public string Id { get; set; } = Guid.NewGuid().ToString();

        public int OriginalMessageId { get; set; }
        public int QuestionMessageId { get; set; }
        public string Text { get; set; }
        public DownloadType Type { get; set; }

        internal string GetDownloadUrl()
        {
            ParseMessageText();

            return _url;
        }

        private void ParseMessageText()
        {
            if (string.IsNullOrEmpty(_url))
            {
                var parts = Text.Split(' ');
                if (parts.Length > 1)
                    _name = string.Join(" ", parts.Take(parts.Length - 1));

                _url = parts.Last();
            }
        }

        internal string GetFolderName(string channelName, bool watchLater)
        {
            ParseMessageText();

            if (!string.IsNullOrEmpty(_name))
                return _name;

            return watchLater ? $"На один раз с {Type}" : channelName;
        }
    }

    public enum DownloadType
    {
        Youtube = 0,
        VK = 1
    }
    public class DownloaderFabric
    {
        public static DownloaderBase CreateDownloader(DownloadType downloadType, AppConfig config)
        {
            switch (downloadType)
            {
                case DownloadType.Youtube:
                    return new YoutubeDownloader(config);
                case DownloadType.VK:
                    return new VKDownloader(config);
                default:
                    throw new NotImplementedException();
            }
        }
    }

    public abstract class DownloaderBase
    {
        protected AppConfig _config;
        protected string _name;

        public async Task<DownloadInfo> GetInfo(string url)
        {
            string rootDownloadFolder = Path.Combine(_config.RootDownloadFolder, _name);

            if (IsPlaylist(url))
                return await GetPlaylistInfo(url, rootDownloadFolder);
            else
                return await GetVideoInfo(url, rootDownloadFolder);
        }

        public  abstract Task Download(string url, string path);

        protected abstract bool IsPlaylist(string url);
        protected abstract Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder);
        protected abstract Task<DownloadInfo> GetVideoInfo(string url, string rootDownloadFolder);

    }
}
