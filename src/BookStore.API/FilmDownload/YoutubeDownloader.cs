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
        public override DownloadType DownloadType { get => DownloadType.Youtube; }
        public override bool IsVideoPropertiesFilled => true;

        public YoutubeDownloader(AppConfig config) : base(config)
        {
        }

        protected override async Task<DownloadInfo> GetVideoInfo(string url, string rootDownloadFolder)
        {
            var result = new DownloadInfo();
            var youtube = new YoutubeClient();

            // You can specify both video ID or URL
            var video = await youtube.Videos.GetAsync(url);
            result.ChannelName = video.Author.ChannelTitle; // "Blender"

            var file = await GetFileFromVideo(video, rootDownloadFolder, result.ChannelName, youtube);
            result.Records.Add(video.Url, file);
            return result;
        }

        private static async Task<VideoFile> GetFileFromVideo(IVideo video, string rootDownloadFolder,string channelName, YoutubeClient youtube)
        {
            var file = new VideoFile();

            file.Name = video.Title; // "Collections - Blender 2.80 Fundamentals"
            file.Duration = video.Duration ?? TimeSpan.Zero; // 00:07:20
            file.VideoFileExtendedInfo = new FileExtendedInfo();
            file.VideoFileExtendedInfo.Description = (video as Video)?.Description;
            file.VideoFileExtendedInfo.ExternalLink = video.Url;

            byte[] imageAsByteArray;
            using (var webClient = new WebClient())
            {
                imageAsByteArray = webClient.DownloadData(video.Thumbnails.Last().Url);
            }
            file.VideoFileExtendedInfo.SetCover(imageAsByteArray);

            var streamManifest = await youtube.Videos.Streams.GetManifestAsync(video.Url);
            // Get highest quality muxed stream
            var streamInfo = streamManifest.GetMuxedStreams().GetWithHighestVideoQuality();

            var path = Path.Combine(rootDownloadFolder, new string(channelName.Where(ch => !Path.InvalidPathChars.Contains(ch) && !Path.GetInvalidFileNameChars().Contains(ch)).ToArray()));
            // TODO 
            path = path.Trim('.');

            var validFilename = new string(video.Title.Where(ch => !Path.GetInvalidFileNameChars().Contains(ch)).ToArray());

            path = Path.Combine(path, validFilename);
            path = path.Trim('.');
            file.Path = $"{path}.{streamInfo.Container}";

            return file;
        }

        protected override async Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder)
        {
            var youtube = new YoutubeClient();
            var result = new DownloadInfo();

            var playlist = await youtube.Playlists.GetAsync(url);

            result.ChannelName = playlist.Title;

            // Get all playlist videos
            var videos = await youtube.Playlists.GetVideosAsync(url);
            foreach (var video in videos)
                result.Records.Add(video.Url, await GetFileFromVideo(video, rootDownloadFolder, playlist.Author.ChannelTitle, youtube));

            return result;
        }

        protected override bool IsPlaylist(string url)
        {
            return url.Contains("playlist");
        }
    }
}
