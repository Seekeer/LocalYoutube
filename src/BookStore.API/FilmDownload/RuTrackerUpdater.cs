using AngleSharp.Html.Parser;
using AngleSharp.Io;
using FileStore.API;
using FileStore.Domain;
using FileStore.Domain.Models;
using HtmlAgilityPack;
using HtmlAgilityPack.CssSelectors.NetCore;
using Infrastructure;
using QBittorrent.Client;
using RuTracker.Client;
using RuTracker.Client.Model.SearchTopics.Request;
using RuTracker.Client.Model.SearchTopics.Response;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web;

namespace API.Controllers
{
    public class VideoInfo {

        public int Id { get; init; }
        public string Url { get; set; }
        public string Name { get; set; }
        public string SeasonName { get; set; }
        public byte[] Cover { get; set; }
        public TimeSpan Duration { get; set; }
        public string Genres { get; set; }
        public string Description { get; set; }
        public int Year { get; set; }
        public string KinopoiskLink { get; set; }
        public string Director { get; set; }
        public string Artist { get; set; }
    }

    public interface IRuTrackerUpdater
    {
        string ClearFromForeignOption(string text);
        Task DeleteTorrent(string id);
        Task<VideoInfo> FillInfo(int topicId);
        Task<IEnumerable<SearchTopicInfo>> FindTheme(string name, bool filterThemes);
        Task Init();
        Task ParseInfo(string html, VideoInfo info);
        Task StartDownload(int id, string rootDownloadFolder);
        Task UpdateVideoFile(bool updateCover, VideoFile file);
    }

    public class RuTrackerUpdater : IRuTrackerUpdater
    {
        private RuTrackerClient _client;
        private QBittorrentClient _qclient;
        private WebProxy _proxy;
        private HttpClient _httpClient;
        private readonly AppConfig _config;

        public RuTrackerUpdater(AppConfig config)
        {
            _config = config;
        }

        public async Task Init()
        {
            _qclient = new QBittorrentClient(new Uri("http://localhost:124"));

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

            try
            {
                _client = new RuTrackerClient(env);
                await _client.Login(_config.RP_Login, _config.RP_Pass);
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }
        }


        public async Task UpdateVideoFile(bool updateCover, VideoFile file)
        {
            var info = await FillInfo(file.VideoFileExtendedInfo.RutrackerId);

            file.Duration = info.Duration;
            file.Name = ClearFromForeignOption(info.Name);
            file.VideoFileExtendedInfo.Director = ClearFromForeignOption(info.Director);
            file.VideoFileExtendedInfo.Year = info.Year;
            file.VideoFileExtendedInfo.Genres = info.Genres;
            file.VideoFileExtendedInfo.Description = info.Description;

            if (file.Duration == System.TimeSpan.Zero)
                file.Duration = DbUpdateManager.GetDuration(file.Path);

            if (updateCover)
                file.VideoFileExtendedInfo.SetCover(info.Cover);
        }

        internal async Task<IEnumerable<TorrentInfo>> Get()
        {
            _qclient = new QBittorrentClient(new Uri("http://localhost:124"));

            var list = await _qclient.GetTorrentListAsync();
            var goodList = list.Where(x => x.AddedOn > new DateTime(2022, 08, 01, 18, 31, 00)).OrderBy(x => x.AddedOn).ToList();

            return goodList.Skip(1).SkipLast(1);
        }

        public async Task<VideoInfo> FillInfo(int topicId)
        {
            //topicId = 4385232;
            var url = $"https://rutracker.org/forum/viewtopic.php?t={topicId}";

            HttpResponseMessage response = await _httpClient.GetAsync(url);
            var buffer = await response.Content.ReadAsByteArrayAsync();
            byte[] bytes = buffer.ToArray();
            Encoding encoding = Encoding.GetEncoding("windows-1251");
            string responseString = encoding.GetString(bytes, 0, bytes.Length);

            //var responseString = await _httpClient.GetStringAsync(url);

            var info = new VideoInfo();
            await ParseInfo(responseString, info);

            return info;
        }

        public async Task ParseInfo(string html, VideoInfo info)
        {
            var doc = new HtmlDocument();
            doc.LoadHtml(html);

            var urls = ParseByText(doc, info);

            if (urls != null)
            {
                foreach (var url in urls.Take(4))
                {
                    if (SetCoverByImageLink(info, url))
                        break;
                }
            }

            await SetCoverByKinopoisk(info);
        }

        private async Task SetCoverByKinopoisk(VideoInfo info)
        {
            return;
            try
            {
                if (string.IsNullOrEmpty(info.KinopoiskLink))
                    return;

                var link = info.KinopoiskLink;
                var doc = new HtmlDocument();

                var response = await _httpClient.GetStringAsync(link);
                doc.LoadHtml(response);

                if (info.Cover?.Length < 8 * 1024)
                {
                    var poster = doc.QuerySelector(".film-poster");
                    var url = poster.GetAttributeValue("src", "");
                    url = $"https:{url}";
                    SetCoverByImageLink(info, url);
                }

                var NameRoot = doc.QuerySelector("[data-test-id=encyclopedic-table]");

                if (NameRoot == null)
                    return;

                var text = "";
                foreach (var child in NameRoot.ChildNodes)
                {
                    if (!string.IsNullOrEmpty(child.InnerText) && child.InnerText != "\n" && child.InnerText != "&#10;")
                        text += child.InnerText + Environment.NewLine;
                }
                var timeStr = GetProperty("Время", text);
                var clearedTimeStr = timeStr.StartingFrom("/").Trim();
                info.Duration = DateTime.ParseExact(clearedTimeStr, "hh:mm", CultureInfo.InvariantCulture).TimeOfDay;

                var title = doc.QuerySelector("[data-tid=75209b22]");
                if (title != null)
                {
                    var titleStr = title.InnerText;
                    var index = titleStr.IndexOf('(');
                    if (index > 0)
                        info.Name = titleStr.Substring(0, index);
                }

            }
            catch (Exception ex)
            {
            }
        }

        private static bool SetCoverByImageLink(VideoInfo info, string url)
        {
            try
            {
                byte[] imageAsByteArray = GetCoverByUrl(url);
                info.Cover = imageAsByteArray;

                return imageAsByteArray.Length > 15 * 1024;
            }
            catch (Exception ex)
            {
                return false;
            }
        }

        public static byte[] GetCoverByUrl(string url)
        {
            byte[] imageAsByteArray;
            using (var webClient = new WebClient())
            {
                imageAsByteArray = webClient.DownloadData(url);
            }

            return imageAsByteArray;
        }

        internal void FillFileInfo(VideoFile file, VideoInfo info)
        {
            file.VideoFileExtendedInfo.Description = info.Description;

            if (info.Cover != null && info.Cover.Length > 30 * 1024)
                //if(file.VideoFileExtendedInfo.Cover.Length < info.Cover?.Length)
                file.VideoFileExtendedInfo.SetCover(info.Cover);
            file.VideoFileExtendedInfo.Genres = info.Genres;
            file.VideoFileExtendedInfo.Year = info.Year;
            file.Duration = info.Duration;

            file.VideoFileExtendedInfo.Director = ClearFromForeignOption(info.Director);
        }

        public string ClearFromForeignOption(string text)
        {
            return text.EndingBefore(@"/").EndingBefore(@"\");
        }

        private IEnumerable<string> ParseByText(HtmlDocument doc, VideoInfo info)
        {
            var NameRoot = doc.QuerySelector(".post_body");
            var text = "";
            foreach (var child in NameRoot.ChildNodes)
            {
                if (!string.IsNullOrEmpty(child.InnerText) && child.InnerText != "\n" && child.InnerText != "&#10;")
                    text += child.InnerText + Environment.NewLine;
            }

            text = HttpUtility.HtmlDecode(text);

            var title = doc.QuerySelector("#topic-title").InnerText;
            info.SeasonName = title.StartingFrom("Сезон", true)?.EndingBefore("/")?.Trim();

            info.Name = text.SplitByNewLine().First();
            if (info.Name.Contains("||") || info.Name.Contains("все релизы") || info.Name.Contains("Rip"))
            {
                var prev = "";
                foreach (var str in text.SplitByNewLine())
                {
                    if (str.Contains("Год выпуска"))
                    {
                        info.Name = prev;
                        break;
                    }
                    else if (prev == "P R E S E N T S")
                    {
                        info.Name = str;
                        break;
                    }

                    prev = str;
                }
            }

            info.Description = GetProperty("Описание", text);
            if (string.IsNullOrEmpty(info.Description))
                info.Description = GetProperty("О фильме", text);
            if (string.IsNullOrEmpty(info.Description))
                info.Description = GetProperty("Сюжет фильма", text);
            if (string.IsNullOrEmpty(info.Description))
                info.Description = GetProperty("Сюжет", text);
            if (string.IsNullOrEmpty(info.Description))
                info.Description = GetProperty("Описание фильма", text);

            var director = GetProperty("Режиссер:", text);
            if (string.IsNullOrEmpty(director))
                director = GetProperty("Режиссёр:", text);
            if (string.IsNullOrEmpty(director))
                director = GetProperty("Режиссёр", text);
            if (string.IsNullOrEmpty(director))
                director = GetProperty("Режиссер", text);
            director = director?.EndingBefore("Роли озвучивали");
            director = director?.EndingBefore("В ролях");
            info.Director = director;

            info.Artist = GetProperty("В ролях", text);
            info.Genres = GetProperty("Жанр", text);
            var duration = GetProperty("Продолжительность", text);
            if (string.IsNullOrEmpty(duration))
                duration = GetProperty("Время", text);
            if (!string.IsNullOrEmpty(duration))
            {
                if (TryParse(duration, out var durationTs))
                    info.Duration = durationTs;
            }

            var yearStr = GetProperty("Год выпуска", text);
            if (string.IsNullOrEmpty(yearStr))
                yearStr = GetProperty("Год выхода", text);
            if (string.IsNullOrEmpty(yearStr))
                yearStr = GetProperty("Год", text);
            if (!string.IsNullOrEmpty(yearStr))
            {
                var yearStrDigits = yearStr.Length > 6 ? yearStr.Substring(0, 6).OnlyDigits() : yearStr.OnlyDigits();
                if (int.TryParse(yearStrDigits, out int year))
                {
                    if (year > 1900 && year < 2030)
                        info.Year = year;
                }
            }
            var urls = doc.QuerySelectorAll(".postImg").Select(x => x.GetAttributeValue("title", null));

            var links = doc.QuerySelectorAll("a");
            var kinopoiskLink = links.Select(x => x.GetAttributeValue("href", "")).FirstOrDefault(x => x.Contains("kinopoisk"));
            if (kinopoiskLink != null)
            {
                var kpUrl = HttpUtility.HtmlDecode(kinopoiskLink).Replace("out.php?url=", "");
                info.KinopoiskLink = kpUrl.Replace(@"/votes", "").Replace("level/1", "");
            }

            return urls;
        }

        public static bool TryParse(string str, out TimeSpan result)
        {
            result = TimeSpan.Zero;

            try
            {
                if (str.Contains("мин"))
                {
                    var parts = str.Split(new char[] { ' ', '~' }, StringSplitOptions.RemoveEmptyEntries);
                    var minutes = int.Parse(parts[0]);

                    result = new TimeSpan(0, minutes, 0);
                    return true;
                }
                if (str.Length > 10)
                {
                    str = str.Substring(0, 8);
                }

                return TimeSpan.TryParse(str, out result);
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);

                return false;
            }
        }

        private string GetProperty(string title, string doc)
        {
            var lines = doc.SplitByNewLine().ToList();
            for (int i = 0; i < lines.Count; i++)
            {
                var line = lines[i];
                if (line.Contains(title))
                {
                    var result = "";
                    if (line == title || line.EndsWith(title) || line.EndsWith(title + ":"))
                    {
                        result = lines[i + 1].Trim(':').Trim();
                        if (string.IsNullOrEmpty(result))
                            result = lines[i + 2];
                        result = result.Trim(':').Trim();
                    }
                    else if (line.Length > title.Length + 3)
                    {
                        var subline = line.StartingFrom(title);
                        result = subline.Trim(':').Trim();
                    }
                    else
                    {
                        continue;
                    }

                    result = result.EndingBefore("Качество видео");
                    result = result.EndingBefore("Качество исходника");
                    result = result.EndingBefore("Релиз");
                    result = result.EndingBefore("Доп. информация");
                    result = result.EndingBefore("Время");

                    return result;
                }
            }

            return null;
        }

        public async Task<IEnumerable<SearchTopicInfo>> FindTheme(string name, bool filterThemes)
        {
            var res = await _client.SearchTopics(new SearchTopicsRequest(
               Title: name,
               SortBy: SearchTopicsSortBy.Downloads,
               SortDirection: SearchTopicsSortDirection.Descending
           ));

            long maxLimit = (long)30 * 1024 * 1024 * 1024;
            long minLimit = (long)1 * 1024 * 1024 * 1024;

            if (res.Topics.Count() < 5)
                return res.Topics;

            var topics = res.Topics.AsEnumerable();
            if (filterThemes)
            {
                topics = topics.Where(x => x.SizeInBytes < maxLimit && x.SizeInBytes > minLimit);
                if (topics.Count() < 3)
                    topics = res.Topics;
            }

            topics = topics.Where(x => !x.Title.Contains("DVD9") && !x.Title.Contains("DVD5"));

            return topics.OrderByDescending(x => x.SizeInBytes).Take(15);
            //return topics.OrderByDescending(x => x.SizeInBytes).Take(10);
            //return topics.OrderByDescending(x => x.SizeInBytes).Take(10);
        }

        public async Task StartDownload(int id, string rootDownloadFolder)
        {
            NLog.LogManager.GetCurrentClassLogger().Info($"Start download to {rootDownloadFolder}");

            var torrent = await _client.GetTopicTorrentFile(id);

            var temp = Path.Combine(rootDownloadFolder, $"{rootDownloadFolder}.torrent");

            File.WriteAllBytes(temp, torrent);

            var request = new AddTorrentFilesRequest();
            request.TorrentFiles.Add(temp);
            request.DownloadFolder = rootDownloadFolder;
            request.Tags = new List<string> { id.ToString() };
            await _qclient.AddTorrentsAsync(request);

            //var args = $"--save-path=\"{rootDownloadFolder}\" --skip-dialog=true {temp}";

            //var process = Process.Start(@"C:\Program Files\qBittorrent\qbittorrent.exe", args);
        }

        public async Task DeleteTorrent(string id)
        {
           var torrents = await _qclient.GetTorrentListAsync();

            var torrent = torrents.FirstOrDefault(x => x.Tags.Contains(id));

            if (torrent != null)
            {
                await _qclient.PauseAsync(torrent.Hash);
                await _qclient.DeleteAsync(torrent.Hash, true);
            }
        }
    }
}
