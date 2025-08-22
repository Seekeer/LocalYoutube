using API.FilmDownload;
using BookStore.Domain.Interfaces;
using FileStore.Domain;
using Moq;
using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Core.Tests.FilmDownload
{
    internal class MishkaTest
    {
        [Test()]
        public async Task CheckDownloadMusic()
        {
            var mockDownloadService = new Mock<IDownloadService>();
            var downloader = new MishkaDownloader(new AppConfig { }, mockDownloadService.Object);
            await downloader.GetPlaylistInfo1("https://mishka-knizhka.ru/pesni-pro-shkolu-i-detskij-sad/", "");
        }

        [Test()]
        public async Task CheckDownloadAbook()
        {
            var mockDownloadService = new Mock<IDownloadService>();
            var downloader = new MishkaDownloader(new AppConfig { }, mockDownloadService.Object);
            await downloader.GetPlaylistInfo1("https://mishka-knizhka.ru/audio-rasskazy-nosova/", "");
        }
    }
}
