using FileStore.API;
using FileStore.Domain.Models;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using YoutubeExplode;
using YoutubeExplode.Converter;
using YoutubeExplode.Videos.Streams;

namespace API.FilmDownload
{
    public class DownloadInfo
    {
        public VideoFile File { get; set; } = new VideoFile();
        public string ChannelName { get; set; }
    }

    public class YoutubeDownloader
    {
        private AppConfig _config;

        public async static Task<DownloadInfo> GetInfo(string url, string rootDownloadFolder)
        {
            var result = new DownloadInfo();

            var youtube = new YoutubeClient();

            // You can specify both video ID or URL
            var video = await youtube.Videos.GetAsync(url);

            result.File.Name = video.Title; // "Collections - Blender 2.80 Fundamentals"
            result.ChannelName = video.Author.ChannelTitle; // "Blender"
            result.File.Duration = video.Duration ?? TimeSpan.Zero; // 00:07:20
            result.File.VideoFileExtendedInfo = new FileExtendedInfo();

            byte[] imageAsByteArray;
            using (var webClient = new WebClient())
            {
                imageAsByteArray = webClient.DownloadData(video.Thumbnails.First().Url);
            }
            result.File.VideoFileExtendedInfo.Cover = imageAsByteArray;

            var streamManifest = await youtube.Videos.Streams.GetManifestAsync(url);
            // Get highest quality muxed stream
            var streamInfo = streamManifest.GetMuxedStreams().GetWithHighestVideoQuality();

            var path = Path.Combine(rootDownloadFolder, result.ChannelName);
            Directory.CreateDirectory(path);
            path = Path.Combine(path, video.Id);
            result.File.Path = $"{path}.{streamInfo.Container}";

            return result;
        }

        internal async static void Download(string url, string path)
        {
            var youtube = new YoutubeClient();

            await youtube.Videos.DownloadAsync(url, path, o => o
                .SetContainer("webm") // override format
                .SetPreset(ConversionPreset.Fast) // change preset
                .SetFFmpegPath(@"C:\Dev\_Smth\BookStore-master\lib\ffmpeg\ffmpeg.exe")); // custom FFmpeg location

            //            var streamManifest = await youtube.Videos.Streams.GetManifestAsync(url);
            //// Get highest quality muxed stream
            //var streamInfo = streamManifest.GetMuxedStreams().GetWithHighestVideoQuality();
            //// Download the stream to a file
            //await youtube.Videos.Streams.DownloadAsync(streamInfo, path);
        }
    }
}
