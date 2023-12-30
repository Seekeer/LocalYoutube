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

        public VKDownloader(AppConfig config)
        {
            _config = config;
        }

        private VkApi _GetApi()
        {
            if (_api == null)
            {
                var services = new ServiceCollection();
                //services.AddAudioBypass();
                //services.AddSingleton<ICaptchaSolver, Solver>();

                var api = new VkApi(services);

                //79366187801:rFdTbLLDgsJxy1
                //api.OnTokenExpires += _api_OnTokenExpires;
                //var token = "vk1.a.aU0anIQj5Tn2mtFxTNqKS4SejEnWC1N42glg6bZqs1EiPyFplM4Yfc85zswZk0CSZ3VGpQSM0geNOOmFJFL5fcktipwo9BNOjc3bHdYHG3sKZuqAUxOkHRB3GciQHKSk2L1peu3FdblDfWc2ho93PN_lLGo1BY59eCOSTLlvP15xbV_-1nmXZnSEF1P4XMEAUvn6ybwbqo0mBeBUO6xBUw";

                api.Authorize(new ApiAuthParams
                {
                    //Login = _config.VkontakteSettings.Login,
                    //Password = _config.VkontakteSettings.Password,
                    Settings = Settings.All,
                    //ApplicationId = 210960361,
                    //ApplicationId = 51448867,

                    AccessToken = "vk1.a.H8D7ZenWSih67WKh5_9SONJVhm9IWeNadB2BsGCn-9ZDNIsvTMXdRe5VjuBQ19FoZTjQ2wndJjD210YSDE40Yi-E-E_pNmxsYITbCTQFDQLdv12EfrlsvP9ysf2hR0_93TzuU-wu-e2AonuRdzwcTtrPEe0SHiU07GsFj_IHjSdl81x58MlJElo5sWMPn_qUiuBbirMxJeYOEfOqGaZ83A",
                    //AccessToken = "vk1.a.XufLN77dVZAKlQ2LaU03qTs2ONr2BhjfLwM0GMc1C72veZaOVlL1fEKoPVGuva3gKAJF4J8WSiPgWyZOV94ca6MD3LxL-2MOMylO4Vm3eRr36pBNsh3KHHJyA24SblNFjN1QGkVZsF8-NgARlk2sI9WwLW8XBsb8YpBqmfs6B3ZhwG1Msa5vz9PnKoCxakXdXR2Q1UEZAzADlvqsPQn1IA",
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

            //url = @"https://vk.com/video-136292562_456239672";

            var idString = url.Replace("https://vk.com/video", "");
            idString = idString.Replace("https://vk.com/video?z=video", "");
            var parts = idString.Split('_', '%', '?');
            var groupId = long.Parse(parts.First());
            var videoId = long.Parse(parts.ElementAt(1));
            var videos = _GetApi().Video.Get(new VideoGetParams
            {
                Extended = true,
                OwnerId = groupId,
                Videos = new List<Video>() { new Video { Id = videoId, OwnerId = groupId } }
                //Videos = new List<Video>() { new Video {  parts.Last() } }
            }) ;

            var info = new DownloadInfo
            {
                ChannelName = "VK",
                IsList = false,
            };

            foreach (var video in videos)
                info.Records.Add(_GetFileUrl(video).ToString(), await GetFileFromVideo(video, rootDownloadFolder, groupId.ToString()));

            return info;
        }

        private async Task<VideoFile> GetFileFromVideo(Video video, string rootDownloadFolder, string channelName)
        {
            var file = new VideoFile();

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
    }

}