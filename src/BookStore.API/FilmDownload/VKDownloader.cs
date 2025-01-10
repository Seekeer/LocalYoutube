using FileStore.Domain;
using Microsoft.Extensions.DependencyInjection;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using VkNet.Enums.Filters;
using VkNet.Model;
using VkNet.Utils.AntiCaptcha;
using VkNet;
using VkNet.AudioBypassService.Extensions;
using System.IO;
using System;
using System.Linq;
using FileStore.Domain.Models;
using Infrastructure;
using System.Net;

namespace API.FilmDownload
{
    public class VKDownloader : DownloaderBase
    {
        public override DownloadType DownloadType { get => DownloadType.VK; }
        public override bool IsVideoPropertiesFilled => true;

        private VkApi _api;

        public VKDownloader(AppConfig config) : base(config)
        {
        }

        private VkApi _GetApi()
        {
            //$"https://vkhost.github.io/"

            if (_api == null)
            {
                var services = new ServiceCollection();
                //services.AddAudioBypass();
                //services.AddSingleton<ICaptchaSolver, Solver>();

                var api = new VkApi(services);

                //79366187801:rFdTbLLDgsJxy1
                //api.OnTokenExpires += _api_OnTokenExpires;

                api.Authorize(new ApiAuthParams
                {
                    //Login = _config.VkontakteSettings.Login,
                    //Password = _config.VkontakteSettings.Password,
                    Settings = Settings.All,
                    //ApplicationId = 210960361,
                    //ApplicationId = 51448867,

                    AccessToken = "vk1.a.EdX1HzRpSn6anH1GMP4LouKCQChe0xeCXohqEe2IFC1CBIggU1ufe0YMbyitDYZzcz4uyt_2g5qw7KUjb14iTGwAOpvWA2oQhhg__WZ4K1NDZ_45VbeWGEe9q1RBIQ_8wlVmU1vQdGfehGe92-rIvxffJ6ycJ--9hGkor5NWvRvksMp2OdB07LewU6q-Q7dRiz3ptPxnmpPZbykbK-W3tw",
                    ApplicationId = 6642456,
                    //Settings = Settings.Wall
                });

                api.MaxCaptchaRecognitionCount = 100;

                _api = api;
            }

            return _api;
        }

        protected override Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder)
        {
            throw new System.NotImplementedException();
        }

        protected override async Task<DownloadInfo> GetVideoInfo(string url, string rootDownloadFolder)
        {
            //https://vk.com/video-220754053_456239513
            //  https://vkvideo.ru/playlist/-114816593_22/video-114816593_456246230

            var initialParts = url.Split("/video");
            var idString = initialParts.Last();
            var parts = idString.Split('_', '%', '?');
            var groupId =long.Parse(parts.First());
            var videoId = long.Parse(parts.ElementAt(1));
            var videos = _GetApi().Video.Get(new VideoGetParams
            {
                Extended = true,
                OwnerId = groupId,
                Videos = new List<Video>() { new Video { Id = videoId, OwnerId = groupId } }
                //Videos = new List<Video>() { new Video {  parts.Last() } }
            }) ;
            var group = _GetApi().Groups.GetById(null, (-groupId).ToString(),  GroupsFields.All);
            var info = new DownloadInfo
            {
                SeasonName = $"VK|{group.FirstOrDefault().Name}",
                ChannelId = Math.Abs(groupId).ToString(),
                IsList = false,
            };

            foreach (var video in videos)
                info.Records.Add(_GetFileUrl(video).ToString(), await GetFileFromVideo(video, rootDownloadFolder, groupId.ToString()));

            return info;
        }

        private async Task<VideoFile> GetFileFromVideo(Video video, string rootDownloadFolder, string channelName)
        {
            var file = new VideoFile { Type = VideoType.ExternalVideo };

            file.Name = video.Title;
            var durationSeconds = video.Duration ?? 0;
            file.Duration = TimeSpan.FromSeconds(durationSeconds);
            file.VideoFileExtendedInfo = new FileExtendedInfo();

            var image = video.Image.OrderByDescending(x => x.Width).First();
            byte[] imageAsByteArray;
            using (var webClient = new WebClient())
            {
                imageAsByteArray = webClient.DownloadData(image.Url);
            }
            file.VideoFileExtendedInfo.SetCover(imageAsByteArray);

            var path = Path.Combine(rootDownloadFolder, new string(channelName.Where(ch => !Path.InvalidPathChars.Contains(ch)).ToArray()));
            Directory.CreateDirectory(path);

            var validFilename = new string(video.Title.Where(ch => !Path.GetInvalidFileNameChars().Contains(ch)).ToArray());

            path = Path.Combine(path, validFilename);
            file.Path = $"{path}.mp4";
            file.Type = VideoType.ExternalVideo;

            return file;
        }

        private Uri _GetFileUrl(Video video)
        {
            return video.Player;

            var files = video.Files;
            return files.Mp4_2160 ?? files.Mp4_1440 ?? files.Mp4_1080 ?? files.Mp4_720 ?? files.Mp4_480 ?? files.Mp4_360 ?? files.Mp4_240 ?? files.External;
        }

        protected override bool IsPlaylist(string url)
        {
            return false;
        }

        internal async Task<Series> AddAudioFromVKGroup(string url, AudioType audioType)
        {
            var idString = url.Replace("https://vk.com/video", "");
            idString = idString.Replace("https://vk.com/video?z=video", "");
            idString = idString.Replace("https://vk.com/wall", "");
            var parts = idString.Split('_', '%', '?');
            var groupId = long.Parse(parts.First());

            string rootDownloadFolder = Path.Combine(_config.RootDownloadFolder, "VK", groupId.ToString());

            var group = _GetApi().Groups.GetById(null, (-groupId).ToString(),  GroupsFields.All);
            var serie = new Series
            {
                AudioType = audioType,
                // TODO
                IsChild = true,
                Name = group.FirstOrDefault()?.Name
            };
            var albums = _GetApi().Audio.GetPlaylists(groupId, count: 100);
            foreach ( var album in albums )
            {
                var season = new Season
                {
                    Name = album.Title,
                };
                season.Series = serie;

                var audios = _GetApi().Audio.Get(new AudioGetParams { OwnerId = (groupId), PlaylistId = album.Id.Value, AccessKey = album.AccessKey });
                foreach (var file in audios)
                {

                    await this.Download("https://vk.com/audio-17232727_456241607_a5fe727c6bbecdb220", @"Z:\VideoServer\VK\asb.mp3");
                }
            }

            return null;
        }
    }

}