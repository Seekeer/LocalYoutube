using API.FilmDownload;
using FileStore.Domain;
using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using TL;

namespace Core.Tests.FilmDownload
{
    internal class MishkaTest
    {
        [Test()]
        public async Task CheckDownloadMusic()
        {
            var downloader = new MishkaDownloader(new AppConfig { });
            await downloader.GetPlaylistInfo1("https://mishka-knizhka.ru/pesni-pro-shkolu-i-detskij-sad/", "");
        }

        [Test()]
        public async Task CheckDownloadAbook()
        {
            var downloader = new MishkaDownloader(new AppConfig { });
            await downloader.GetPlaylistInfo1("https://mishka-knizhka.ru/audio-rasskazy-nosova/", "");
        }
    }
}
