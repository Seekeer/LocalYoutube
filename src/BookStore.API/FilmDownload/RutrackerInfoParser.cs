using HtmlAgilityPack;
using HtmlAgilityPack.CssSelectors.NetCore;
using Infrastructure;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using System.Web;

namespace API.Controllers
{
    public class VideoInfo : RutrackerInfo
    {
        public string SeasonName { get; set; }
        public string Genres { get; set; }
        public string KinopoiskLink { get; set; }
        public string Director { get; set; }
        public string Artist { get; set; }
    }
    public class AudioInfo : RutrackerInfo
    {
        public string BookTitle { get; set; }
        public string Author { get; set; }
        public string Voice { get; set; }
    }

    public class RutrackerInfo
    {
        public int Id { get; init; }
        public string Url { get; set; }
        public string Name { get; set; }
        public byte[] Cover { get; set; }
        public TimeSpan Duration { get; set; }
        public string Description { get; set; }
        public int Year { get; set; }
    }

    public class RutrackerInfoParser
    {
        public async Task<VideoInfo> ParseVideoInfo(string html)
        {
            VideoInfo info = new VideoInfo();
            var doc = new HtmlDocument();
            doc.LoadHtml(html);

            var urls = ParseVideoByText(doc, info);

            if (urls != null)
            {
                foreach (var url in urls.Take(4))
                {
                    if (SetCoverByImageLink(info, url))
                        break;
                }
            }

            return info;
        }
        public async Task<AudioInfo> ParseAudioInfo(string html)
        {
            var info = new AudioInfo();
            var doc = new HtmlDocument();
            doc.LoadHtml(html);

            var urls = ParseAudioByText(doc, info);

            if (urls != null)
            {
                foreach (var url in urls.Take(4))
                {
                    if (SetCoverByImageLink(info, url))
                        break;
                }
            }

            return info;
        }

        private IEnumerable<string> ParseAudioByText(HtmlDocument doc, AudioInfo info)
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
                info.Name = title.EndingBefore("/")?.Trim();

            info.Description = GetProperty("Описание", text);

            var director = GetProperty("Исполнитель:", text);
            if (string.IsNullOrEmpty(director))
                director = GetProperty("Режиссёр:", text);
            if (string.IsNullOrEmpty(director))
                director = GetProperty("Режиссёр", text);
            if (string.IsNullOrEmpty(director))
                director = GetProperty("Режиссер", text);
            director = director?.EndingBefore("Роли озвучивали");
            director = director?.EndingBefore("В ролях");
            info.Director = director;

            var name = GetProperty("В ролях", text);
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

        private IEnumerable<string> ParseVideoByText(HtmlDocument doc, VideoInfo info)
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
            if (!title.Contains("Сезон"))
                info.Name = title.EndingBefore("/")?.Trim();
            else
            {
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

        private static bool SetCoverByImageLink(RutrackerInfo info, string url)
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

    }
}
