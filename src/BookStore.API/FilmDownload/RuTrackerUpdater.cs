using AngleSharp.Html.Parser;
using FileStore.API;
using HtmlAgilityPack;
using HtmlAgilityPack.CssSelectors.NetCore;
using Infrastructure;
using RuTracker.Client;
using RuTracker.Client.Model.SearchTopics.Request;
using RuTracker.Client.Model.SearchTopics.Response;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace API.Controllers
{
    public class VideoInfo {

        public int Id { get; init; }
        public string Url { get; set; }
        public string Name { get; set; }
        public byte[] Cover { get; set; }
        public string Genres { get; set; }
        public string Description { get; set; }
        public int Year { get; set; }
    }

    public class RuTrackerUpdater
    {
        private RuTrackerClient _client;
        private WebProxy _proxy;
        private HttpClient _httpClient;
        private readonly AppConfig _config;

        public RuTrackerUpdater(AppConfig config)
        {
            _config = config;
        }

        public async Task Init ()
        {
            _proxy = new WebProxy
            {
                Address = new Uri($"http://serv.bitterman.ru:3128"),
                BypassProxyOnLocal = false,
                UseDefaultCredentials = false,

                // *** These creds are given to the proxy server, not the web server ***
                Credentials = new NetworkCredential(
                userName: "timonin",
                password: "BzNwuL4hrLgs")
            };

            // Now create a client handler which uses that proxy
            var httpClientHandler = new HttpClientHandler
            {
                Proxy = _proxy,
                UseProxy = true,
            };

            // Finally, create the HTTP client object
            _httpClient = new HttpClient(handler: httpClientHandler, disposeHandler: true);
            RuTrackerClientEnvironment env = new RuTrackerClientEnvironment(_httpClient, new Uri(@"https://rutracker.org"));

            _client = new RuTrackerClient(env);
            await _client.Login(_config.RP_Login, _config.RP_Pass);
        }

        public async Task<VideoInfo> FillInfo(SearchTopicInfo topic)
        {
            var url = $"https://rutracker.org/forum/viewtopic.php?t={topic.Id}";
            var response = await _httpClient.GetStringAsync(url);

            var info = new VideoInfo();
            ParseInfo(response, info);

            return info;
        }

        private void ParseInfo(string html, VideoInfo info)
        {
            var doc = new HtmlDocument();
            doc.LoadHtml(html);

           var url = ParseByText(doc, info);
           //var url = ParseByHTML(doc, info);

            if (url != null)
            {
                try
                {
                    byte[] imageAsByteArray;
                    using (var webClient = new WebClient())
                    {
                        imageAsByteArray = webClient.DownloadData(url);
                    }
                    info.Cover = imageAsByteArray;
                }
                catch (Exception ex)
                {

                }
            }
        }

        private string ParseByText(HtmlDocument doc, VideoInfo info)
        {
            var NameRoot = doc.QuerySelector(".post_body");
            var text = "";
            foreach (var child in NameRoot.ChildNodes)
            {
                if(!string.IsNullOrEmpty(child.InnerText) && child.InnerText != "\n" && child.InnerText != "&#10;")
                    text += child.InnerText + Environment.NewLine;
            }

            info.Name = text.SplitByNewLine().First();
            info.Description = GetProperty("Описание", text);
            if (string.IsNullOrEmpty(info.Description))
                info.Description = GetProperty("О фильме", text);
            info.Genres = GetProperty("Жанр", text);
            if (int.TryParse(GetProperty("Год выпуска", text), out int year))
                info.Year = year;
            var url = doc.QuerySelector(".postImg")?.GetAttributeValue("title", null);

            return url;
        }

        private string GetProperty(string title, string doc)
        {
            var lines = doc.SplitByNewLine().ToList();
            for (int i = 0; i < lines.Count; i++)
            {
                var line = lines[i];
                if (line.Contains(title))
                {
                    if (line == title || line.EndsWith(title) || line.EndsWith(title+":"))
                    {
                        var result = lines[i + 1].Trim(':').Trim();
                        if (string.IsNullOrEmpty(result))
                            result = lines[i + 2];
                        return result.Trim(':').Trim(); ;
                    }
                    else if(line.Length > title.Length + 3)
                    {
                        var subline = line.StartingFrom(title);
                        return subline.Trim(':').Trim(); ;
                    }
                     
                }
            }

            return null;
        }

        private string ParseByHTML(HtmlDocument doc, VideoInfo info)
        {
            var NameRoot = doc.QuerySelector(".post_body");

            info.Name = NameRoot.ChildNodes.FirstOrDefault()?.InnerText;

            var treeRootElement = doc.QuerySelector(".post-font-serif1");

            info.Description = GetProperty("Описание", treeRootElement);
            info.Genres = GetProperty("Жанр", treeRootElement);
            if (int.TryParse(GetProperty("Год выпуска", treeRootElement), out int year))
                info.Year = year;
            var url = doc.QuerySelector(".postImg")?.GetAttributeValue("src", null);

            return url;
        }

        private string GetProperty(string title, HtmlNode doc)
        {
            var all = doc.QuerySelectorAll(".post-b");
            var element = all.Where(x => x.InnerText == title);

            for (int i = 0; i < doc.ChildNodes.Count; i++)
            {
                if(doc.ChildNodes[i].InnerText == title)
                {
                    var text = doc.ChildNodes[i + 1].InnerText;
                    if (text == ":")
                        text = doc.ChildNodes[i + 3].InnerText;

                    return text.Trim(':').Trim();
                }
            }

            return null;
        }

        public async Task<IEnumerable<SearchTopicInfo>> FindTheme(string name)
        {
            var res = await _client.SearchTopics(new SearchTopicsRequest(
               Title: name,
               SortBy: SearchTopicsSortBy.Downloads,
               SortDirection: SearchTopicsSortDirection.Descending
           ));

            long maxLimit = (long)12 * 1024 * 1024 * 1024;
            long minLimit = (long)2 * 1024 * 1024 * 1024;

            var topics = res.Topics.Where(x => x.SizeInBytes < maxLimit && x.SizeInBytes > minLimit);

            return topics;
        }

        public async Task StartDownload(SearchTopicInfo videoInfo, string rootDownloadFolder)
        {
            var torrent = await _client.GetTopicTorrentFile(videoInfo.Id);

            var temp = Path.GetTempFileName();
            File.WriteAllBytes( temp, torrent);

            var args = $"--save-path=\"{rootDownloadFolder}\" --skip-dialog=true {temp}";

            Process.Start(@"C:\Program Files\qBittorrent\qbittorrent.exe", args);

            Thread.Sleep(TimeSpan.FromSeconds(10));
            File.Delete(temp);
        }
    }
}
