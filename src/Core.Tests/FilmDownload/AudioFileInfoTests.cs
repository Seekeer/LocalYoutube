using API.Controllers;
using Infrastructure;
using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Core.Tests.FilmDownload
{
    [TestFixture()]
    internal class AudioFileInfoTests
    {

        [Test()]
        public async Task ParseName()
        {
            var result = new AudioFileInfo("Манн Томас - Волшебная гора [Терновский Евгений, 2013 г., 96 kbps, MP3]");

            Assert.AreEqual("Манн Томас", result.Author);
            Assert.AreEqual("Волшебная гора", result.BookTitle);
            //Assert.AreEqual("Терновский Евгений", result.Voice);
        }
        [Test()]
        public async Task ParseName2()
        {
            var result = new AudioFileInfo("Пушкин Александр - Борис Годунов (1950 г.). Маленькие трагедии (1978 г. - 1982 г.) [Яншин М., Высоцкий В. и др., 2006 г., 192 kbps, MP3]");

            Assert.AreEqual("Пушкин Александр", result.Author);
            Assert.AreEqual("Борис Годунов", result.BookTitle);
        }
        [Test()]
        public async Task ParseName3()
        {
            var result = new AudioFileInfo("Антон Чехов - Дуэль.2007.Александр Андриенко");

            Assert.AreEqual("Антон Чехов", result.Author);
            //Assert.AreEqual("Дуэль", result.BookTitle);
            //Assert.AreEqual("Александр Андриенко", result.Voice);
        }
        [Test()]
        public async Task ParseName4()
        {
            var result = new AudioFileInfo("Антон Чехов - Дуэль (чит. Владимир Самойлов)");

            Assert.AreEqual("Антон Чехов", result.Author);
            Assert.AreEqual("Дуэль", result.BookTitle);
            Assert.AreEqual("Владимир Самойлов", result.Voice);
        }
        [Test()]
        public async Task ParseName5()
        {
            var result = new AudioFileInfo("Трое в лодке, не считая собаки (В.Самойлов, АРДИС)" +
                "");

            Assert.AreEqual("Трое в лодке, не считая собаки", result.BookTitle);
            Assert.AreEqual("В.Самойлов", result.Voice);
        }
    }
}
