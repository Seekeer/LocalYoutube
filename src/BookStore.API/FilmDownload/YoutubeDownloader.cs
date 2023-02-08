using FileStore.API;
using FileStore.Domain.Models;
using Google.Apis.CustomSearchAPI.v1.Data;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using YoutubeExplode;
using YoutubeExplode.Common;
using YoutubeExplode.Converter;
using YoutubeExplode.Videos;
using YoutubeExplode.Videos.Streams;

namespace API.FilmDownload
{
    public class DownloadInfo
    {
        public string ChannelName { get; set; }
        public string ListName { get; set; }
        public bool IsList { get; set; }

        public Dictionary<string, VideoFile> Records { get; set; } = new Dictionary<string, VideoFile>();
    }

    public class YoutubeDownloader
    {
        private AppConfig _config;

        public async static Task<DownloadInfo> GetInfo(string url, string rootDownloadFolder)
        {
            if (url.Contains("playlist"))
                return await GetPlaylistInfo(url, rootDownloadFolder);
            else
                return await GetVideoInfo(url, rootDownloadFolder) ;
        }

        private static async Task<DownloadInfo> GetVideoInfo(string url, string rootDownloadFolder)
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

            byte[] imageAsByteArray;
            using (var webClient = new WebClient())
            {
                imageAsByteArray = webClient.DownloadData(video.Thumbnails.Last().Url);
            }
            file.VideoFileExtendedInfo.Cover = imageAsByteArray;

            var streamManifest = await youtube.Videos.Streams.GetManifestAsync(video.Url);
            // Get highest quality muxed stream
            var streamInfo = streamManifest.GetMuxedStreams().GetWithHighestVideoQuality();

            var path = Path.Combine(rootDownloadFolder, new string(channelName.Where(ch => !Path.InvalidPathChars.Contains(ch)).ToArray()));
            Directory.CreateDirectory(path);

            var validFilename = new string(video.Title.Where(ch => !Path.GetInvalidFileNameChars().Contains(ch)).ToArray());

            path = Path.Combine(path, validFilename);
            file.Path = $"{path}.{streamInfo.Container}";

            return file;
        }

        private static async Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder)
        {
            var youtube = new YoutubeClient();
            var result = new DownloadInfo();

            var playlist = await youtube.Playlists.GetAsync(url);

            result.ChannelName = playlist.Title;

            // Get all playlist videos
            var videos = await youtube.Playlists.GetVideosAsync(url);
            foreach (var video in videos)
                result.Records.Add(video.Url, await GetFileFromVideo(video, rootDownloadFolder, result.ChannelName, youtube));

            return result;
        }

        internal async static Task Download(string url, string path)
        {
            var youtube = new YoutubeClient();

            // Low Quality

            //await youtube.Videos.DownloadAsync(url, path, o => o
            //    .SetContainer("webm") // override format
            //    .SetPreset(ConversionPreset.Fast) // change preset
            //    .SetFFmpegPath(@"C:\Dev\_Smth\BookStore-master\lib\ffmpeg\ffmpeg.exe")); // custom FFmpeg location

            // Get stream manifest
            var streamManifest = await youtube.Videos.Streams.GetManifestAsync(url);

            // Select streams (1080p60 / highest bitrate audio)
            var audioStreamInfo = streamManifest.GetAudioStreams().GetWithHighestBitrate();
            var videoStreamInfo = streamManifest.GetVideoStreams().FirstOrDefault(s => s.VideoQuality.MaxHeight == 1080);
            if (videoStreamInfo == null)
            {
                videoStreamInfo = streamManifest.GetVideoStreams().OrderBy(s => s.VideoQuality.MaxHeight).First();
            }
            var streamInfos = new IStreamInfo[] { audioStreamInfo, videoStreamInfo };

           await youtube.Videos.DownloadAsync(streamInfos, new ConversionRequest(@"F:\Видео\Фильмы\Загрузки\lib\ffmpeg\ffmpeg.exe", path, new Container("webm"), ConversionPreset.UltraFast));
        }
    }
}
