using FileStore.Domain.Models;
using Google.Apis.CustomSearchAPI.v1;
using Google.Apis.CustomSearchAPI.v1.Data;
using Google.Apis.Services;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace API.FilmDownload
{
    public class SearchResult
    {
        public DbFile File { get; set; }
        public string Url { get; internal set; }
        public Bitmap Bitmap { get; internal set; }
        public long TgId { get; internal set; }
        public int TgMessageId { get; internal set; }
    }

    internal class SearchEngine
    {
        private readonly string _id;
        private CustomSearchAPIService _service;

        public SearchEngine(string id, string key)
        {
            _id = id;
            _service = new CustomSearchAPIService(new BaseClientService.Initializer
            {
                ApiKey = key,
            });

        }

        internal IEnumerable<SearchResult> Search(string searchTerm, string searchTerm2)
        {
            var resultItems = _Search(searchTerm);

            if (!resultItems.Any())
                resultItems = _Search(searchTerm2);

            try
            {
                resultItems = resultItems.Where(x => x.Pagemap != null);
                var imagesData = resultItems.Select(x => x.Pagemap.FirstOrDefault(y => y.Key == "cse_image")).Where(x => x.Key != null).ToList();
                var imageRoots = imagesData.Select(x => JsonSerializer.Deserialize<List<CseImage>>(x.Value.ToString())).ToList();

                var src = imageRoots.Select(x => (x.FirstOrDefault()?.src));
                var images = src.Select(x => new SearchResult { Url = x, Bitmap = GetImage(x) }).Where(x => x.Bitmap != null).ToList();

                var filtered = images.Where(x => x.Bitmap?.Height > x.Bitmap?.Width && x.Bitmap?.Height > 500 && x.Bitmap?.Height < 900);
                if (!filtered.Any())
                    filtered = images;

                filtered = filtered.Where(x => x.Bitmap.Height > 200).OrderByDescending(x => x.Bitmap.Height).ToList();
                return filtered;
            }
            catch (Exception ex)
            {
                return new List<SearchResult>() ;
            }
        }

        private Bitmap GetImage(string url)
        {
            if (string.IsNullOrEmpty(url))
                return null;

            try
            {
                byte[] imageAsByteArray;
                using (var webClient = new WebClient())
                {
                    imageAsByteArray = webClient.DownloadData(url);
                }

                return new Bitmap(new MemoryStream(imageAsByteArray));
            }
            catch (Exception ex)
            {
                return null;
            }
        }

        public static async Task<bool> IsRemoteFileAvailable(string url)
        {
            //Checking if URI is well formed is optional
            Uri uri = new Uri(url);
            if (!uri.IsWellFormedOriginalString())
                return false;

            using (HttpClient client = new HttpClient())
            {
                HttpResponseMessage response = await client.GetAsync(url);

                return response.IsSuccessStatusCode;
            }
        }

        private IEnumerable<Result> _Search(string searchTerm)
        {
            var listRequest = _service.Cse.List();

            listRequest.Cx = _id;
            listRequest.ImgSize = CseResource.ListRequest.ImgSizeEnum.XXLARGE;
            listRequest.Q = searchTerm;
            listRequest.Num = 10;
            listRequest.ImgType = CseResource.ListRequest.ImgTypeEnum.Clipart;

            // Result set 1
            listRequest.Start = 1;
            var search = listRequest.Execute();

            return (search.Items);
        }
    }

    // Root myDeserializedClass = JsonConvert.DeserializeObject<Root>(myJsonResponse);
    public class CseImage
    {
        public string src { get; set; }
    }

    public class CseThumbnail
    {
        public string src { get; set; }
        public string width { get; set; }
        public string height { get; set; }
    }

    public class Metatag
    {
        public string referrer { get; set; }

        [JsonPropertyName("og:image")]
        public string OgImage { get; set; }

        [JsonPropertyName("theme-color")]
        public string ThemeColor { get; set; }

        [JsonPropertyName("og:image:width")]
        public string OgImageWidth { get; set; }

        [JsonPropertyName("og:type")]
        public string OgType { get; set; }
        public string viewport { get; set; }

        [JsonPropertyName("og:title")]
        public string OgTitle { get; set; }

        [JsonPropertyName("og:image:height")]
        public string OgImageHeight { get; set; }

        [JsonPropertyName("format-detection")]
        public string FormatDetection { get; set; }
    }

    public class Pagemap
    {
        public List<CseThumbnail> cse_thumbnail { get; set; }
        public List<Metatag> metatags { get; set; }
        public List<CseImage> cse_image { get; set; }
    }
}
