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
using YoutubeExplode;
using YoutubeExplode.Common;
using YoutubeExplode.Converter;
using YoutubeExplode.Videos;
using YoutubeExplode.Videos.Streams;

namespace API.FilmDownload
{
    public class YoutubeDownloader : DownloaderBase
    {
        public YoutubeDownloader(AppConfig config)
        {
            this._config = config;
            _name = "Youtube";
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

            byte[] imageAsByteArray;
            using (var webClient = new WebClient())
            {
                imageAsByteArray = webClient.DownloadData(video.Thumbnails.Last().Url);
            }
            file.VideoFileExtendedInfo.SetCover(imageAsByteArray);

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

        protected override async Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder)
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

        public override async Task Download(string url, string path)
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

        protected override bool IsPlaylist(string url)
        {
            return url.Contains("playlist");
        }
    }
}
