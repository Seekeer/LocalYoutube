using FileStore.API;
using FileStore.Domain;
using FileStore.Domain.Models;
using Google.Apis.CustomSearchAPI.v1.Data;
using Infrastructure;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using VkNet.Exception;
using YoutubeExplode;
using YoutubeExplode.Common;
using YoutubeExplode.Converter;
using YoutubeExplode.Videos;
using YoutubeExplode.Videos.Streams;

namespace API.FilmDownload
{
    public class YoutubeDownloader : DownloaderBase
    {
        private readonly bool _ignoreShortVideos;

        public override DownloadType DownloadType { get => DownloadType.Youtube; }
        public override bool IsVideoPropertiesFilled => true;

        public YoutubeDownloader(AppConfig config, bool ignoreShortVideos) : base(config)
        {
            _ignoreShortVideos = ignoreShortVideos;
        }

        public static string GetCoverUrl(string videoId)
        {
            return $"https://i.ytimg.com/vi/{videoId}/maxresdefault.jpg";
        }

        public static string GetVideoUrl(string videoId)
        {
            return $"https://www.youtube.com/watch?v={videoId}";
        }

        protected override async Task<DownloadInfo> GetVideoInfo(string url, string rootDownloadFolder)
        {
            var result = new DownloadInfo();

            using (var httpClient = ProxyManager.GetHttpClientWithProxy())
            {
                var youtube = new YoutubeClient(httpClient);

                // You can specify both video ID or URL
                var video = await youtube.Videos.GetAsync(url);

                if (_ignoreShortVideos && video.Duration != null && video.Duration < TimeSpan.FromMinutes(1.2))
                    return result;

                result.SeasonName = video.Author.ChannelTitle;
                result.ChannelId = video.Author.ChannelId;

                var file = await GetFileFromVideo(video, rootDownloadFolder, result.SeasonName, youtube);
                result.Records.Add(video.Url, file);
                return result;
            }
        }

        private static async Task<VideoFile> GetFileFromVideo(IVideo video, string rootDownloadFolder,string channelName, YoutubeClient youtube)
        {
            var file = new VideoFile { Type = VideoType.ExternalVideo};

            file.Name = video.Title; // "Collections - Blender 2.80 Fundamentals"
            file.Duration = video.Duration ?? TimeSpan.Zero; // 00:07:20
            file.VideoFileExtendedInfo = new FileExtendedInfo();
            file.VideoFileExtendedInfo.Description = (video as Video)?.Description;
            file.VideoFileExtendedInfo.ExternalLink = video.Url;

            try
            {
                byte[] imageAsByteArray;
                using (var httpClient = ProxyManager.GetHttpClientWithProxy())
                {
                    try
                    {
                        imageAsByteArray = await httpClient.GetByteArrayAsync(video.Thumbnails.LastOrDefault()?.Url);
                    }
                    catch (Exception ex)
                    {
                        NLog.LogManager.GetCurrentClassLogger().Error(ex,$"GetFileFromVideo Thumbnail Url:{video.Thumbnails.LastOrDefault()?.Url}");
                        string coverUrl = YoutubeDownloader. GetCoverUrl(video.Id);
                        imageAsByteArray = await httpClient.GetByteArrayAsync(coverUrl);
                    }
                }

                file.SetCover(imageAsByteArray);
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex, $"GetFileFromVideo Thumbnail Url:{video.Thumbnails.LastOrDefault()?.Url}");
            }

            //var streamManifest = await youtube.Videos.Streams.GetManifestAsync(video.Url);
            //// Get highest quality muxed stream
            //var streamInfo = streamManifest.GetMuxedStreams().GetWithHighestVideoQuality();

            var path = Path.Combine(rootDownloadFolder, channelName.GetCorrectFilePath());
            // TODO 
            path = path.Trim('.');

            var validFilename = video.Id.Value.GetCorrectFileName();

            path = Path.Combine(path, validFilename);
            path = path.Trim('.');
            file.Path = $"{path}.mp4";

            return file;
        }

        protected override async Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder)
        {
            using (var httpClient = ProxyManager.GetHttpClientWithProxy())
            {
                var youtube = new YoutubeClient(httpClient);
                var result = new DownloadInfo();

                var playlist = await youtube.Playlists.GetAsync(url);

                result.SeasonName = playlist.Title;

                // Get all playlist videos
                var videos = await youtube.Playlists.GetVideosAsync(url);
                foreach (var video in videos)
                    result.Records.Add(video.Url, await GetFileFromVideo(video, rootDownloadFolder, playlist.Author.ChannelTitle, youtube));

                return result;
            }
        }

        protected override bool IsPlaylist(string url)
        {
            return url.Contains("playlist");
        }
    }
}
