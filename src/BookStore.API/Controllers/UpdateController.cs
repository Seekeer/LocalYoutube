using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Infrastructure;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FileStore.API.Controllers
{
    [EnableCors()]
    [Route("api/[controller]")]
    public class UpdateController : MainController
    {
        private readonly VideoCatalogDbContext _db;

        public UpdateController(VideoCatalogDbContext dbContext)
        {
            _db = dbContext;
        }

        [HttpGet]
        [Route("convertToLower")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> ConvertToLower()
        {
            var sourceRoot = @"F:\Анюта\Мульты\Мультсериалы российские";
            var destinationRoot = @"F:\Анюта\Мульты\LowRes\Мультсериалы российские\";

            var task = new List<string>();
            task.Add(@"\Пластилинки\Пластилинки Азбука (А-Я) Никола-фильм");
            task.Add(@"\Пластилинки\Пластилинки. Зверушки.2019.WEBRip 1080p");
            task.Add(@"\Пластилинки\Пластилинки. Машинки.2019.WEBRip 1080p");
            task.Add(@"\Пластилинки\Пластилинки. Музыкальные инструменты.2019.WEBRip 1080p");
            task.Add(@"\Пластилинки\Пластилинки. Растения.2020.WEB-DL 1080p");
            task.Add(@"\Пластилинки\Пластилинки. Музыкальные инструменты.2019.WEBRip 1080p");
            task.Add(@"\Пластилинки\Пластилинки. Циферки.2018.WEBRip 1080p");
            task.Add(@"\Бумажки 1-78 1080p");
            task.Add(@"\Смешарики 1-218 1080p");

            foreach (var dir in task)
            {
                var rootDir = (sourceRoot + dir);
                var newFolder = (destinationRoot + dir);
                foreach (var file in Directory.GetFiles(rootDir))
                {
                    DbUpdateManager.EncodeFile(file, newFolder, FFMpegCore.Enums.VideoSize.Hd);
                }
            }

            return Ok();
        }

        [HttpGet]
        [Route("updateAll")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateAll()
        {
            var dbUpdater = new DbUpdateManager(_db);
            GiveNameForEmpty(dbUpdater);

            ClearSerie(dbUpdater, 1025);
            dbUpdater.FillSeries(@"F:\Анюта\Мульты\Мультсериалы российские\Три кота.2015.WEBRip 1080p", Origin.Russian, VideoType.ChildEpisode, false);
            dbUpdater.FillSeries(@"F:\Анюта\Мульты\Мультсериалы российские\Фиксики Сезоны 1-3 720p 4 1080p", Origin.Russian, VideoType.ChildEpisode, false);

            UpdateSeriesStructure(dbUpdater);

            //Convert(dbUpdater);

            UpdateSeries(dbUpdater);

            //ClearLinks(dbUpdater);

            //_db.RemoveRange(films.Select(x => x.VideoFileExtendedInfo));
            //_db.RemoveRange(films.Select(x => x.VideoFileUserInfo).Where(x => x != null));
            //_db.RemoveRange(films);
            //_db.SaveChanges();
            //var series = _db.Series.Where(x => x.Id == 11);
            //_db.RemoveRange(series);
            //_db.SaveChanges();

            //Convert(dbUpdater);5

            //dbUpdater.FillSeries(@"D:\Анюта\Мульты\Мультсериалы российские", Origin.Russian, VideoType.Episode);

            ////dbUpdater.FillFilms(@"D:\Анюта\Мульты\Советские мультфильмы\Солянка", Origin.Soviet, VideoType.Animation);
            //dbUpdater.FillFilms(@"D:\Анюта\Мульты\Советские мультфильмы\Известные", Origin.Soviet, VideoType.Animation);
            //dbUpdater.FillSeries(@"D:\Media\Обучалки\Съемка", Origin.Russian, VideoType.Lessons);

            //dbUpdater.FillSeries(@"D:\Анюта\Мульты\Советские мультфильмы\Солянка", Origin.Soviet, VideoType.Animation);

            //var files = _db.Files.Where(x => x.Id > 0);
            //foreach (var file in files)
            //{
            //    file.Path = file.Path.Replace(@"D:\Анюта\Мульты", @"F:\Анюта\Мульты");
            //}
            //_db.SaveChanges();

            //dbUpdater.FillSeries(@"F:\Анюта\Мульты\Мультсериалы российские\Фиксики Сезоны 1-3 720p 4 1080p", Origin.Russian, VideoType.Episode, false);
            //_db.SaveChanges();


            //dbUpdater.FillSeries(@"D:\Мульты\YandexDisk\Анюта\Советские мультфильмы\Мультсериалы", Origin.Soviet, VideoType.Episode);
            //dbUpdater.FillFilms(@"D:\Мульты\YandexDisk\Анюта\Фильмы-Сказки", Origin.Soviet, VideoType.FairyTale);


            return Ok();
        }

        private void GiveNameForEmpty(DbUpdateManager dbUpdater)
        {
            var films= _db.VideoFiles.Where(x => x.Name == null || x.Name == "");
            foreach (var item in films)
            {
                var finfo = new FileInfo(item.Path);
                item.Name = finfo.Name;
            }

            _db.SaveChanges();
        }

        private void UpdateSeries(DbUpdateManager dbUpdater)
        {
            dbUpdater.FillSeries(@"F:\Видео\Балет", Origin.Russian, VideoType.Balley, false);
            dbUpdater.FillSeries(@"F:\Видео\Фильмы", Origin.Unknown, VideoType.Film, true);

            //dbUpdater.FillSeries(@"F:\Видео\Фильмы", Origin.Unknown, VideoType.Film, false);

            //var fairyTale = @"F:\Анюта\Фильмы\В гостях у сказки";
            //MoveUp(fairyTale);
            //dbUpdater.FillSeries(fairyTale, Origin.Soviet, VideoType.FairyTale, false);

            //dbUpdater.FillSeries(@"F:\Анюта\Мульты\Мультсериалы российские\Царевны", Origin.Russian, VideoType.Episode, false);

        }

        private void UpdateSeriesStructure (DbUpdateManager dbUpdater)
        {
            var series = _db.Series.ToList();
            foreach (var serie in series)
            {
                var film = _db.VideoFiles.FirstOrDefault(x => x.SeriesId == serie.Id);

                if (film == null)
                {
                    _db.Series.Remove(serie);
                    continue;
                }

                serie.Origin = film.Origin;
                serie.Type = film.Type;
                serie.Name = serie.Name.ClearSerieName();
                serie.IsChild = true;
            }

            _db.SaveChanges();

            //_db.Series.Add(new Series { Name = "Просто фильмы", Type = VideoType.Film });
            //_db.Series.Add(new Series { Name = "Ликбез", Type = VideoType.Film });
        }


        private void ClearLinks(DbUpdateManager dbUpdater)
        {
            var files = _db.Files.Include(x => x.VideoFileUserInfo).Include(x => x.VideoFileExtendedInfo).ToList();

            foreach (var file in files)
            {
                if (!System.IO.File.Exists(file.Path))
                {
                    _db.FilesUserInfo.Remove(file.VideoFileUserInfo);
                    _db.FilesInfo.Remove(file.VideoFileExtendedInfo);
                    _db.Files.Remove(file);
                }
            }

            _db.SaveChanges();
        }
        private void ClearSerie(DbUpdateManager dbUpdater, int serieId)
        {
            var files = _db.Files.Include(x => x.VideoFileUserInfo).Include(x => x.VideoFileExtendedInfo).Where(x => x.SeriesId == serieId).ToList();

            foreach (var file in files)
            {
                _db.FilesUserInfo.Remove(file.VideoFileUserInfo);
                _db.FilesInfo.Remove(file.VideoFileExtendedInfo);
                _db.Files.Remove(file);
            }

            foreach (var season in _db.Seasons.Where(x => x.SeriesId == serieId).ToList())
                _db.Seasons.Remove(season);

            foreach (var item in _db.Series.Where(x => x.Id == serieId).ToList())
                _db.Series.Remove(item);

            _db.SaveChanges();
        }

        private void MoveUp(string fairyTale)
        {
            var root = new DirectoryInfo(fairyTale);
            foreach (var file in root.GetFiles("*", SearchOption.AllDirectories))
            {
                file.MoveTo(file.FullName.Replace(".avi..avi", ".avi"));
                //var newFileName = Path.Combine(fairyTale, $"{file.Name}");
                //file.MoveTo(newFileName);
            }
        }

        private void Convert(DbUpdateManager dbUpdater)
        {
            var mp4Count = _db.VideoFiles.Count(x => !x.Path.EndsWith("mp4"));
            var totalCount = _db.VideoFiles.Count();

            var convert = _db.VideoFiles.Where(x => !x.Path.EndsWith("mp4") && !x.Path.EndsWith(".mkv")).ToList();
            //var sovietToConvert = _db.Files.Where(x => x.Path.Contains("Советские мультфильмы") && !x.Path.EndsWith("mp4")).ToList();
            //var nonSovietToConvert = _db.Files.Where(x => !x.Path.Contains("Советские мультфильмы") && !x.Path.EndsWith("mp4")).ToList();
            //Parallel.ForEach(convert, file =>
            foreach (var file in convert)
            {
                dbUpdater.Convert(file);
            }
            //);

            //var nonSovietToConvertList = _db.Files.Where(x => !x.Path.Contains("Советские мультфильмы") && !x.Path.EndsWith("mp4")).ToList();
            //var totalDuration = _db.Files.Where(x => !x.Path.Contains("Советские мультфильмы") && !x.Path.EndsWith("mp4")).ToList().Sum(x => x.Duration.TotalMinutes);

        }
    }
}