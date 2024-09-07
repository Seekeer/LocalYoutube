using AngleSharp.Text;
using FileStore.Domain;
using FileStore.Domain.Models;
using HtmlAgilityPack;
using HtmlAgilityPack.CssSelectors.NetCore;
using Infrastructure;
using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text.Json.Nodes;
using System.Threading;
using System.Threading.Tasks;

namespace API.FilmDownload
{
    public class MishkaDownloader : PageDownloaderBase
    {

        public MishkaDownloader(AppConfig config) : base(config, new WebDriverPageLoader(TimeSpan.FromSeconds(3), false)) { }

        public override async Task<string> Download(string url, string path)
        {
            var httpClient = new HttpClient();
            Thread.Sleep(1000);
            var response = await httpClient.GetAsync(url);
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

        public Task<DownloadInfo> GetPlaylistInfo1(string url, string rootDownloadFolder)
        {
            return GetPlaylistInfo(url, rootDownloadFolder);
        }
        protected override async Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder)
        {
            var html = GetHTML(url);

            var result = new DownloadInfo();
            result.ChannelName = html.DocumentNode.QuerySelector(".page-title")?.InnerText ?? html.DocumentNode.QuerySelector(".entry-title-post")?.InnerText;
            var folderPath = rootDownloadFolder.AddFolder(result.ChannelName);

            var musicCard = html.DocumentNode.QuerySelectorAll(".article-inf-song");
            foreach (var card in musicCard)
            {
                var link = card.QuerySelector("a");

                string trackLink = link.GetAttributeValue("href", "");
                var info = CreateAudioInfo(card, trackLink, folderPath);
                if (info != null)
                    result.Records.Add(trackLink, info);
            }

            var allCards = html.DocumentNode.QuerySelectorAll(".post-item-wrap");
            foreach (var card in allCards)
            {
                var link = card.QuerySelector("a");

                string trackLink = link.GetAttributeValue("href", "");
                var info = CreateAudioInfo(card, trackLink, folderPath);
                if(info != null) 
                    result.Records.Add(trackLink, info);
            }

            var nextPageButton = html.DocumentNode.QuerySelector(".next.page-numbers");

            if (nextPageButton != null)
            {
                var nextPage = (await GetPlaylistInfo(nextPageButton.GetHREF(), rootDownloadFolder));
                result.Records = new System.Collections.Generic.Dictionary<string, DbFile>(result.Records.Union(nextPage.Records));
            }

            return result;
        }

        private AudioFile CreateAudioInfo(HtmlNode card, string trackLink, string folderPath)
        {
            var file = new AudioFile();

            var html = GetHTML(trackLink);
            var jsonContainer = html.DocumentNode.QuerySelector(".entry-content");
            var script = jsonContainer.QuerySelector("script");
            var json = script.InnerText;

            JsonNode? deserializedToken = System.Text.Json.JsonSerializer.Deserialize<JsonNode>(json);
            var audios = deserializedToken["audio"].AsArray();
            if(audios.Count > 1)
            {
                return null;
            }
            var musicLink = audios[0]["src"].ToString();

            var link = card.QuerySelector("a");
            file.Name = link.GetAttributeValue<string>("Title",null) ?? link.InnerText.ClearSpaces();
            var durationEl = card.QuerySelector(".plr-app-time--duration");
            if(durationEl != null)
                file.Duration = durationEl.InnerText.ParseTS();

            file.VideoFileExtendedInfo = new FileExtendedInfo();
            file.VideoFileExtendedInfo.ExternalLink = musicLink;

            var img = html.QuerySelector(".article-inner img") ?? card.QuerySelector(".article-inner img");
            byte[] imageAsByteArray;
            using (var webClient = new WebClient())
            {
                imageAsByteArray = webClient.DownloadData(img.GetAttributeValue("src", ""));
            }
            file.VideoFileExtendedInfo.SetCover(imageAsByteArray);

            var validFilename = file.Name.GetCorrectFileName();

            var path = Path.Combine(folderPath, validFilename);
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