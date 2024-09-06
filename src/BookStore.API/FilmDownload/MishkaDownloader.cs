using FileStore.Domain;
using FileStore.Domain.Models;
using HtmlAgilityPack;
using HtmlAgilityPack.CssSelectors.NetCore;
using Infrastructure;
using Microsoft.Extensions.Options;
using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text.Json.Nodes;
using System.Threading.Tasks;
using VkNet.Model;

namespace API.FilmDownload
{
    internal class MishkaDownloader : PageDownloaderBase
    {

        public MishkaDownloader(AppConfig config) : base(config, new WebDriverPageLoader(TimeSpan.FromSeconds(3), false)) { }

        public override async Task<string> Download(string url, string path)
        {
            var html = GetHTML(url);
            var jsonContainer = html.DocumentNode.QuerySelector(".plr-json");
            var json = jsonContainer.ChildNodes.First().InnerText;

            JsonNode? deserializedToken = System.Text.Json.JsonSerializer.Deserialize<JsonNode>(json);
            var musicLink = deserializedToken["audio"][0]["src"].ToString();
            var httpClient = new HttpClient();
            var response = await httpClient.GetAsync(musicLink);
            var finfo = new FileInfo(path);
            Directory.CreateDirectory(finfo.DirectoryName);
            using (var fs = new FileStream(path, FileMode.CreateNew))
            {
                await response.Content.CopyToAsync(fs);
            }

            return path;
        }

        protected override bool IsPlaylist(string url)
        {
            return true;
        }

        protected override async Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder)
        {
            var html = GetHTML(url);

            var allCards = html.DocumentNode.QuerySelectorAll(".post-item-wrap");
            var result = new DownloadInfo();
            result.ChannelName = html.DocumentNode.QuerySelector(".page-title").InnerText;

            var folderPath = rootDownloadFolder.AddFolder(result.ChannelName);
            foreach (var card in allCards)
            {
                var link = card.QuerySelector("a");

                result.Records.Add(link.GetAttributeValue("href",""), CreateAudioInfo(card, folderPath));
            }

            var nextPageButton = html.DocumentNode.QuerySelector(".next.page-numbers");

            if (nextPageButton != null)
            {
                var nextPage = (await GetPlaylistInfo(nextPageButton.GetHREF(), rootDownloadFolder));
                result.Records = new System.Collections.Generic.Dictionary<string, DbFile>(result.Records.Union(nextPage.Records));
            }

            return result;
        }

        private AudioFile CreateAudioInfo(HtmlNode card, string rootDownloadFolder)
        {
            var file = new AudioFile();

            var link = card.QuerySelector("a");
            file.Name = link.GetAttributeValue("Title",""); 
            file.Duration = card.QuerySelector(".plr-app-time--duration").InnerText.ParseTS();

            file.VideoFileExtendedInfo = new FileExtendedInfo();
            //file.VideoFileExtendedInfo.ExternalLink = video.Url;

            //byte[] imageAsByteArray;
            //using (var webClient = new WebClient())
            //{
            //    imageAsByteArray = webClient.DownloadData(video.Thumbnails.Last().Url);
            //}
            //file.VideoFileExtendedInfo.SetCover(imageAsByteArray);

            var validFilename = file.Name.GetCorrectFileName();

            var path = Path.Combine(rootDownloadFolder, validFilename);
            path = path.Trim('.');
            file.Path = $"{path}.mp3";

            return file;
        }

        protected override Task<DownloadInfo> GetVideoInfo(string url, string rootDownloadFolder)
        {
            throw new NotImplementedException();
        }

        public override DownloadType DownloadType => DownloadType.Mishka;

        public override bool IsVideoPropertiesFilled => true;
    }
}