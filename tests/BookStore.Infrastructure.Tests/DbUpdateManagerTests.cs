using Infrastructure;
using System;
using System.Collections.Generic;
using System.Text;
using Xunit;

namespace BookStore.Infrastructure.Tests
{
    public class DbUpdateManagerTests
    {

        [Fact]
        public async void NameIsGood1()
        {
            var name = "Смешарики WEBRip 1080p";
            var result = DbUpdateManager.GetSeriesNameFromFolder(name);

            Assert.Equal("Смешарики", result);
        }

        [Fact]
        public async void NameIsGood2()
        {
            var name = "Смешарики. Пин-код.2012-2018.WEB-DL 1080p";
            var result = DbUpdateManager.GetSeriesNameFromFolder(name);

            Assert.Equal("Смешарики. Пин-код", result);
        }

        [Fact]
        public async void NameIsGood3()
        {
            var name = "Три Кота (2015)";
            var result = DbUpdateManager.GetSeriesNameFromFolder(name);

            Assert.Equal("Три Кота", result);
        }

        [Fact]
        public async void NameIsGood4()
        {
            var name = "Приключения Винни Пуха";
            var result = DbUpdateManager.GetSeriesNameFromFolder(name);

            Assert.Equal("Приключения Винни Пуха", result);
        }

        [Fact]
        public async void VideoNameIsGood1()
        {
            var name = "001 Скамейка.mp4";
            var result = DbUpdateManager.GetSeriesNameFromFilenName(name);

            Assert.Equal("Скамейка", result);
        }

        [Fact]
        public async void VideoNameIsGood2()
        {
            var name = "010 Забытая история.mp4";
            var result = DbUpdateManager.GetSeriesNameFromFilenName(name);

            Assert.Equal("Забытая история", result);
        }

        [Fact]
        public async void VideoNameIsGood3()
        {
            var name = "20. IQ (Коэффициент интеллекта).mp4";
            var result = DbUpdateManager.GetSeriesNameFromFilenName(name);

            Assert.Equal("IQ (Коэффициент интеллекта)", result);
        }

        [Fact]
        public async void VideoNameIsGood4()
        {
            var name = "29. Откуда берется мед.mp4";
            var result = DbUpdateManager.GetSeriesNameFromFilenName(name);

            Assert.Equal("Откуда берется мед", result);
        }

        [Fact]
        public async void VideoNameIsGood5()
        {
            var name = "02. 10 лет грязных луж. Золотые сапожки.2014.XviD.SATRip.mp4";
            var result = DbUpdateManager.GetSeriesNameFromFilenName(name);

            Assert.Equal("10 лет грязных луж. Золотые сапожки", result);
        }

        [Fact]
        public async void VideoNameIsGood6()
        {
            var name = "Бумажки  003 - Игрушка для Зюйд-веста.mp4";
            var result = DbUpdateManager.GetSeriesNameFromFilenName(name);

            Assert.Equal("Бумажки - Игрушка для Зюйд-веста", result);
        }



        [Fact]
        public async void VideoNumberIsGood1()
        {
            var name = "001 Скамейка.mp4";
            var result = DbUpdateManager.GetSeriesNumberFromName(name);

            Assert.Equal(1, result);
        }

        [Fact]
        public async void VideoNumberIsGood2()
        {
            var name = "010 Забытая история.mp4";
            var result = DbUpdateManager.GetSeriesNumberFromName(name);

            Assert.Equal(10, result);
        }

        [Fact]
        public async void VideoNumberIsGood3()
        {
            var name = "20. IQ (Коэффициент интеллекта).mp4";
            var result = DbUpdateManager.GetSeriesNumberFromName(name);

            Assert.Equal(20, result);
        }

        [Fact]
        public async void VideoNumberIsGood4()
        {
            var name = "29. Откуда берется мед.mp4";
            var result = DbUpdateManager.GetSeriesNumberFromName(name);

            Assert.Equal(29, result);
        }

        [Fact]
        public async void VideoNumberIsGood5()
        {
            var name = "02. 10 лет грязных луж. Золотые сапожки.2014.XviD.SATRip.mp4";
            var result = DbUpdateManager.GetSeriesNumberFromName(name);

            Assert.Equal(2, result);
        }

        [Fact]
        public async void VideoNumberIsGood6()
        {
            var name = "Бумажки  003 - Игрушка для Зюйд-веста.mp4";
            var result = DbUpdateManager.GetSeriesNumberFromName(name);

            Assert.Equal(3, result);
        }
    }
}
