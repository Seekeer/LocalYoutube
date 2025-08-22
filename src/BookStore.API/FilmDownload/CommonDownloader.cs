using BookStore.Domain.Interfaces;
using FileStore.Domain;
using FileStore.Domain.Models;
using HtmlAgilityPack;
using Infrastructure;
using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace API.FilmDownload
{
    public class RossaDownloader : CommonDownloader
    {

        public RossaDownloader(AppConfig config, IDownloadService downloadService) : base(config, new RossaDownloadService(downloadService)) { }

        public override DownloadType DownloadType => DownloadType.Rossaprimavera;
    }

    public class CommonDownloader : DownloaderBase
    {
        public CommonDownloader(AppConfig config, IDownloadService downloadService) :base(config, downloadService)
        {
        }

        public override DownloadType DownloadType => DownloadType.Common;

        public override bool IsVideoPropertiesFilled => false;

        protected override async Task<DownloadInfo> GetVideoInfo(string url, string rootDownloadFolder)
        {
            Uri.TryCreate(url, UriKind.Absolute, out Uri uriResult);

            var info = new DownloadInfo
            {
                SeasonName = uriResult.Host
            };

            info.Records.Add(url, GetFileInfo(uriResult, rootDownloadFolder));

            return info;
        }

        private VideoFile GetFileInfo(Uri uri, string rootDownloadFolder)
        {
            var file = new VideoFile { Type = VideoType.ExternalVideo };

            file.Name = uri.OriginalString.Replace(uri.Host, string.Empty).Replace("https:", "").Replace("video", "").Replace("/","");
            HtmlWeb web = new HtmlWeb();
            var htmlDoc = web.Load(uri);
            var headers = htmlDoc.DocumentNode.SelectNodes("//meta")  ;
            //var headers = htmlDoc.DocumentNode.SelectNodes("//div[*[video]]");
            //var headers = htmlDoc.DocumentNode.SelectNodes("//div[video]/following-sibling:://h3");
            //var headers = htmlDoc.DocumentNode.SelectNodes("//h1 | //h2 or //h3 or //h4 or //h5 or //h6");
            if (headers != null && headers.Any())
            {
                foreach ( var header in headers)
                {
                    var attr = header.GetAttributeValue("property", "");
                    if (!string.IsNullOrEmpty(attr))
                    {
                        if (attr == "og:title")
                        {
                            file.Name = header.GetAttributeValue("content", "");
                            break;
                        }
                    }

                    attr = header.GetAttributeValue("itemprop", "");
                    if (!string.IsNullOrEmpty(attr))
                    {
                        if (attr == "name")
                        {
                            file.Name = header.GetAttributeValue("content", "");
                            break;
                        }
                    }
                }
            }
            else
            {
                var title = htmlDoc.DocumentNode.SelectNodes(".//*[@id=\"title\"]");
            }

            file.VideoFileExtendedInfo = new FileExtendedInfo();

            var path = Path.Combine(rootDownloadFolder, new string(uri.Host.Where(ch => !Path.InvalidPathChars.Contains(ch)).ToArray()));
            Directory.CreateDirectory(path);

            var validFilename = new string(file.Name.Where(ch => !Path.GetInvalidFileNameChars().Contains(ch)).ToArray());

            path = Path.Combine(path, validFilename);
            file.Path = $"{path}.mp4";

            return file;
        }

        protected override bool IsPlaylist(string url)
        {
            return false;
        }

        protected override Task<DownloadInfo> GetPlaylistInfo(string url, string rootDownloadFolder)
        {
            throw new System.NotImplementedException();
        }
    }
}