using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using API.Controllers;
using API.FilmDownload;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Infrastructure;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.Authorization;

namespace FileStore.API.Controllers
{
#if DEBUG
    [EnableCors("CorsPolicy")]
    [AllowAnonymous]
    [Route("api/[controller]")]
    public class UpdateController : MainController
    {
        private readonly VideoCatalogDbContext _db;
        private readonly AppConfig _config;
        private readonly IServiceScopeFactory _serviceScopeFactory;

        public UpdateController(VideoCatalogDbContext dbContext, AppConfig config, IServiceScopeFactory serviceScopeFactory)
        {
            _db = dbContext;
            _config = config;
            _serviceScopeFactory = serviceScopeFactory;
        }

        [HttpGet]
        [Route("checkDownloaded")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> CheckDownloaded()
        {
            var files = _db.VideoFiles.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).
                Where(x => x.Type == VideoType.Film).ToList();
            foreach (var file in files)
            {
                if(!System.IO.File.Exists(file.Path))
                    _db.VideoFiles.Remove(file);
            }

            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("updateDownloaded")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> CheckDownloaded(string seriesName)
        {
            var files = _db.VideoFiles.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos)
                .Where(x => x.IsDownloading).ToList();
            foreach (var info in files)
            {
                try
                {
                    var dir = new DirectoryInfo(info.Path);

                    if (!dir.Exists)
                    {
                        Remove(info);
                        continue;
                    }

                    var dirFiles = dir.EnumerateFiles("*", SearchOption.AllDirectories);

                    // Delete file if not exist
                    if (!dirFiles.Any())
                    {
                        Remove(info);
                        dir.Delete();
                        continue;
                    }

                    if (!dirFiles.Any() || dirFiles.Any(x => x.FullName.EndsWith(".!qB")))
                        continue;

                    var dbUpdater = new DbUpdateManager(_db);
                    var biggestFile = dirFiles.OrderByDescending(x => x.Length).First();

                    info.Path = biggestFile.FullName;
                    info.IsDownloading = false;
                }
                catch (System.Exception ex)
                {
                }
            }

            _db.SaveChanges();

            return Ok();
        }


        [HttpDelete]
        [Route("removeSeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public void RemoveSeason(int seasonId, bool deleteFile)
        {
            var files = _db.Files.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).Where(x => x.SeasonId == seasonId).ToList();

            var manager = new DbUpdateManager(_db);
            foreach (var file in files)
            {
                manager.RemoveFileCompletely(file);

                if (deleteFile)
                    System.IO.File.Delete(file.Path);
            }

            var seriesId = 0;
            var season = _db.Seasons.First(x => x.Id == seasonId);
            _db.Seasons.Remove(season);
            if (!_db.Seasons.Any(x => x.SeriesId == season.SeriesId))
            {
                var serie = _db.Series.First(x => x.Id == season.SeriesId);
                _db.Series.Remove(serie);
            }

            _db.SaveChanges();
        }

        [HttpDelete]
        [Route("removeSeries")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> RemoveSeries(int serieId, bool deleteFile)
        {
            var dbManager = new DbUpdateManager(_db);

            var files = _db.Files.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).
                Where(x => x.SeriesId == serieId).ToList();
            foreach (var file in files)
            {
                if (deleteFile)
                    await PhisicallyRemoveFile(file);
            }
            dbManager.RemoveSeriesCompletely(serieId);

            return Ok();
        }

        [HttpDelete]
        [Route("removeFile")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> RemoveFile(int fileId)
        {
            var file = _db.Files.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).First(x => x.Id == fileId);

            await PhisicallyRemoveFile(file);
            Remove(file);

            _db.SaveChanges();

            return Ok();
        }

        private async Task PhisicallyRemoveFile(DbFile file)
        {
            if (file.VideoFileExtendedInfo.RutrackerId > 0)
            {
                var _rutracker = new RuTrackerUpdater(_config);
                await _rutracker.Init();
                await _rutracker.DeleteTorrent(file.VideoFileExtendedInfo.RutrackerId.ToString());
            }
            else
                System.IO.File.Delete(file.Path);
        }

        [HttpDelete]
        [Route("removeFiles")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> RemoveFile(int startId, int endId, bool removeFile)
        {
            var files = _db.Files.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).Where(x => x.Id >= startId && x.Id <= endId).ToList();

            foreach (var file in files)
            {
                if (removeFile && System.IO.File.Exists(file.Path))
                    System.IO.File.Delete(file.Path);
                
                Remove(file);
            }

            _db.SaveChanges();

            return Ok();
        }

        private void Remove(DbFile file)
        {
            var manager = new DbUpdateManager(_db);
            manager.RemoveFileCompletely(file); 
        }

        [HttpGet]
        [Route("changeDownloadedType")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> ChangeDownloadedType(string seriesName)
        {
            new DbUpdateManager(_db).MoveDownloadedToAnotherSeries(VideoType.Film, seriesName ?? "Добавленные фильмы");

            return Ok();
        }

        [HttpGet]
        [Route("addFolder")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> AddFolder(string path, VideoType? type = null, bool severalSeriesInFolder = false, string seriesName = null)
        {
            var dbUpdater = new DbUpdateManager(_db);

            if (type == VideoType.ChildEpisode || type == VideoType.Courses)
            {
                dbUpdater.FillSeries(path, Origin.Russian, type.Value, severalSeriesInFolder, seriesName);
                return Ok();
            }

            return NotFound();
        }

        [HttpGet]
        [Route("updateTracks")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateTracks()
        {
            var dbUpdater = new DbUpdateManager(_db);

            var audios = _db.AudioFiles.ToList();
            foreach (var audio in audios)
            {
                dbUpdater.UpdateAudioInfo(audio);

                _db.SaveChanges();
            }

            return Ok();
        }

        [HttpGet]
        [Route("addFile")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> AddFile(string path, VideoType? type = null)
        {
            var dbUpdater = new DbUpdateManager(_db);

            dbUpdater.FillSeries(path, Origin.Soviet, type.Value, false, "Загрузки");

            return Ok();
        }


        [HttpGet]
        [Route("moveCompleteSeries")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveCompleteSeries(int seriesId, int newSeriesId)
        {
            var dbUpdater = new DbUpdateManager(_db);

            var seasons = _db.Seasons.Where(x => x.SeriesId == seriesId).Include(x => x.Files).ToList();

            foreach (var item in seasons)
            {
                item.SeriesId = newSeriesId;

                foreach (var file in item.Files)
                {
                    file.SeriesId = newSeriesId; 
                }
            }

            _db.SaveChanges();

            var series = _db.Series.FirstOrDefault(x =>x.Id == seriesId);
            _db.Remove(series);
            _db.SaveChanges();

            return Ok();
        }


        [HttpGet]
        [Route("moveToSeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveToSeason(int startId, int finishId, int seasonId, int seriesId = 0, VideoType? type = null, string seasonName = null)
        {
            var dbUpdater = new DbUpdateManager(_db);

            var files = _db.VideoFiles.Where(x => x.Id >= startId && x.Id <= finishId).ToList();
            foreach (var file in files)
            {
                //if(string.IsNullOrEmpty(seasonName))
                file.SeasonId = seasonId;
                //else if (seriesId != 0)
                //{
                //    var series = _db.Series.FirstOrDefault(x => x.Id == seriesId);
                //    var season = dbUpdater.AddOrUpdateSeason(series, seasonName);
                //    file.SeasonId = season.Id;
                //}

                if (seriesId != 0)
                    file.SeriesId = seriesId;
                if (type != null)
                    file.Type = type.Value;
            }

            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("updateByExistingRutracker")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateByExistingRutracker(bool updateCover)
        {
            var _rutracker = new RuTrackerUpdater(_config);
            await _rutracker.Init();

            //var files = _db.VideoFiles.Include(x => x.VideoFileUserInfo).Include(x => x.VideoFileExtendedInfo).Where(x => x.Id == 3852).ToList();
            var files = _db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).Where(x => x.VideoFileExtendedInfo.RutrackerId != 0).ToList();

            foreach (var file in files.OrderBy(x => x.Duration))
            {
                try
                {
                    await _rutracker.UpdateVideoFile(updateCover, file);

                    _db.SaveChanges();
                }
                catch (System.Exception ex)
                {
                }
            }

            return Ok();
        }

        //[HttpGet]
        //[Route("addNonExistingRutracker")]
        //[ProducesResponseType(StatusCodes.Status200OK)]
        //public async Task<IActionResult> AddNonExistingRutracker(bool updateCover)
        //{
        //    var _rutracker = new RuTrackerUpdater(_config);
        //    await _rutracker.Init();

        //    var dbUpdater = new DbUpdateManager(_db);
        //    await dbUpdater.FillByRutrackerDownload(@"F:\Видео\Фильмы\Загрузки", _rutracker);

        //    return Ok();
        //}

        [HttpGet]
        [Route("updateByRutrackerMass")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateByRutracker(string filenames)
        {
//            filenames = @"Его девушка Пятница        ___https://kinopoisk-ru.clstorage.net/1z4G6O223/1cbe98RE-zCm/PX9DNh72cZjg3OOWux-YFcI8y-WhRRu8p7pCyqvBO9fN8GBhCGuIJL9qseD9LQ3quyhA0aLY23TXBsbA5S_0g0kaVscPg9TdAb0Tpk4v6fE37N-EFcB__XaPl39ZMjlU72dCAvrpiuKrXvWRKPiYHrodwGDyLB8A4CUn8kGpUbevTRA3CtSx-3cMYxRozLnREswr4MGm6_gXy4DqGBLLdm-2MqGb-WgB2I7FpytI28zJTUJC4ltssYLk88BQSbOnrTwRJfl2sMlkXfGUCs-60eBfmrNjt7m6FGpCydmCyYVs1gKw2hjK0-g9FWU6mMg_y60SQ-EarDNRpLEBknuAV2yd8HeJNOP5VX5ABPtvmDHC_Rvh8fY4yfVKQhvKYNp3nnfTUwrLGtB4Xfalaoi7vomd8eKh2H5jgSRxkpDbAtUMD-L1-VTxeKSM8ybb_ssj8r7aQFEW2NikWqK7K4Gb9W4F4CJZeKjwaQ0EtFkbC195fHHRc6rvc4MWoFJCSIFUbR3CZjlGwnuHvNIHWx8rIfB-uGARZno6F9qy2wmBGSStxoAA23tIoWkcJnUIOBpsGg-yAyO4TgHhNLLRIMlg5v7_o7ULJmM7Vqzzlws_6ONBjTgBIhUJ-NY64GsaErlWr9WiIwqKekB63yVnq-hYbwvdgCJQO2wRQMZxgbC5E_dvX8NEOQTzSpafsyZ6XmrhUm5qQ8EkGDiV2FJoGIPZ9C02Q2N62ZkzSS00dKiaGEw7zqCj8BjMg8CHgqHCSoFmXo7DRliFkZumrNOmydypU2P-KaJT1Cir1yiACTiAS2TNV9KxuPupIQhdpeVqahoOmD1xgrI6HOGB5JDwwnhzRt2-cXQZlNN497_gx3n9O8GCngmzQ5dq6Lca8ogq4xkF7_TD8qgYyvLpH5WnCihbXwpfcHKTCk8BcEaDI4A4AVS8D9GEazQAyeUM43Yr3Qjxgu5ZM_EVKAg2CcNIyENZtC0VsnLKq2lzahzXxGpZOF3Z_LCT8qguQxHFgsIjmAE0DB2jJ2tUsvjkvDL3y66709O9qsJDJNuqlkpiafmTaFR_NGLhG0rK0MqfBeVKC1mfy79iIPCp7WIwl4CzEhoxNO8NYbVbt6HpZh0jxUpuWIIzXfgjEpU6KdZaoVv44as2vYWj8JsamDHaXfYkSskp71odQ7FD-gxTwyQDkaC5UwR9n7AFqqSDuPRe4Lc6_-gwgc-agSBWWuk2anGKS2D79k3EYlF6CFgDGM4VtIhZCmw7nbPhA8oMchNGILGw6XDHDP3C9Dsl40lUndAHCf8Z4KH_6GMSZHnKVDvCiUpRazTOJMHTm2p4g-m8lra56yhumF-Bg2EZ30EC54KRw4gARgyOMOV4xmN7lO4TNrl-i4BgHvshMwcJyRXIAMj7kup2zeRQo7ga6mLY7-WEiWqYjGpsQDNiOi8TIHWiwkGJoNR8HeKGWTcjaIW9Qzc5vYqyQa3r4ZOV-ihHaDJJCiN45gwX8qGJO7gSyoyFRkoZKmxqbKDCkYtdctN0w2OiKZNHvb3RVRuEkfk23lFGy7048nGP2TJgp6p6R4jguwtBO1Z8ZCGjaMlIUOp9JgWYOUqteD3DU-MIf6DhBCExwHgDpB2sACe7ZvEY1x8DRMjcasJRrxoR8pTZmNaLcXvKAQnH_STwo3soikC6_OYVGdk7_vveAMDTCmxy05WyoCLKMbSNPNAGORRQSOZvwTV7nKnTkr5a0WFViFpXGUEryLHp1__HgnGI2MlQOV_n1Mhq28yJ7yHzI-gdE5HkooCBe2Nk7Q-SBjp086uVH2EG-SyYw3Cs66MBh4iJJamAyLgzufZMJ7BjyAlZcOjsFcWrKtmPGw5i4NCKjEGRZuBjg4njBJ-uQ7U5V5Lo1t_AhLvMicBgfrrwEYeZWNSqUohr4GlUP6SQg5qpCNC6vtaXCisqXtguUMMxyK9hIoWCwdA7weesfwCUCgfSiQZdA3fI36vjYv2qYXNne9gWWbJJGBHrBd3kYcMrKXig-z3WtZkbOJyKfnAgQQre4rCUUVIDK5DGD62RZRgnALtEnhPEOU_owLDPyzGDV5gZd5viqXmT2SfvVKCSqPjawKqvRKXaWUmuWr-gM2OYnSCjFbKCk4vD5Qx9QjRKBFErlt8iBCtsi8CzrcvzsfVYWfe6kylpwdrkjtagU5j6mDEabdRHCehabwvekgLh6Xzjo7XicHGL0EZ9nMGUG4eAuSTvwuaazljSQcyKkMBl2-q3-uCbeeMp9N4G4APrO7tx2I-2pRlpSh8YbSKxYItu44KlwOPgG-P2T2xi9UrW8flGHUMXaU0psbOt2PJBZ1t4tblxqSqx6sbMBEDBqei5MRrslFaLC6t9CY-S0mBafVKil-Ly8GtB9g0dk5dq1hF6x11S5qocyeNwv_jz0CTayFfrg7qrgJo33BaR4lrL6BBZjOSW-JspXOmcQfBDif7zIqYxkoMJY5Uev7KXqCUBqWSv4AVLzNtxMo-78nGnOHoHyYJ6evNYFk424FCqy3lR2vzGhys5Kj0KLQGDMkpeUYNnwnDwilN1Tm_Rd6kl8WsEbBMFaB9LI8GfqFMjd5o4V_jjShgg-bVcVmOQ-tkoYFgOt7WJWSrOWExR0ZPL_VAzd8EjwEoR9m5_sWZbhzM45k2wpHpuyxGiLrgAYWR42fZpQOja8soHXHYAQev6yDDZTaZm6jrb7BhvcOLxCiyBU2fjI9K4IYcsvDD0OFaSWFW_spaLLyoDwl7L0HGla8hWaMFquJFJBd_UUmFbWMsSml0EJEsY2dx6bHKxIbosk0CkoHIg-6NnTJ5i9Ao2cLvkrwMGac1qohOPigIAlXtrRdjDOHnzSAYtVIBA6Br48Llf5GdrCPoOen0R4OIYLoOA9AEjkmixha6v4gc5NDEaRE9g9onNmBBiT4oDghdo2wSIwGtI0LmWzhUSsUjIaxHaDfW2mxh4PIieQHDyKuyjc#DSD
//Last.Year.at.Marienbad.1961.720p.BluRay.Rus.French.HDCLUB.mkv ___http://media7.veleto.ru/media/files/s2/ru/lp/v-proshlom-godu-v-marienbade.jpg";
            var lines = filenames.SplitByNewLine();

            var _rutracker = new RuTrackerUpdater(_config);
            await _rutracker.Init();

            foreach (var line in lines)
            {
                try
                 {
                    var parts = line.Split("___", System.StringSplitOptions.RemoveEmptyEntries);

                    var name = parts[0].Trim();

                    var file = _db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).First(x => x.Name == name);

                    //file.VideoFileExtendedInfo.Cover = RuTrackerUpdater.GetCoverByUrl(parts[1].Trim());

                    var id = parts.Length > 1 ? int.Parse(parts[1]) : file.VideoFileExtendedInfo.RutrackerId;

                    if (id == 0)
                        continue;

                    //file.VideoFileExtendedInfo.RutrackerId = id;
                    var info = await _rutracker.FillInfo(id);
                    _rutracker.FillFileInfo(file, info);

                    _db.SaveChanges();
                }
                catch (System.Exception ex)
                {
                }
            }

            return Ok();
        }

        [HttpGet]
        [Route("updateByRutrackerId")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateByRutrackerId(int fileId)
        {
            var _rutracker = new RuTrackerUpdater(_config);
            await _rutracker.Init();

            var file = _db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).First(x => x.Id == fileId);

            var info = await _rutracker.FillInfo(file.VideoFileExtendedInfo.RutrackerId);
            _rutracker.FillFileInfo(file, info);

            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("test")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task Test()
        {
            //var files = _db.VideoFiles.Include(x => x.VideoFileUserInfo).Include(x => x.VideoFileExtendedInfo).Where(x => x.VideoFileExtendedInfo.RutrackerId != 0);
            //foreach (var file in files)
            //{
            //    await UpdateByRutracker(file.Name);
            //}

            var films = _db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).Where(x => x.Id >= 11433 || x.Id <= 11437);
            foreach (var film in films)
            {
                Remove(film);
            }

            //var series = _db.Series.Where(x => x.Id == 1040 || x.Id == 2042).Include(x => x.Seasons).Include(x => x.Files).ToList();
            //foreach (var serie in series)
            {
                //foreach (var file in serie.Files)
                //{
                //    Remove(file);
                //    System.IO.File.Delete(file.Path);

                //}

                //foreach (var season in serie.Seasons)
                //    _db.Seasons.Remove(season);

                //_db.Series.Remove(serie);
            }

            _db.SaveChanges();
        }

        [HttpGet]
        [Route("convertOnline")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> ConvertNewOnline(int minId = 19812)
        {
            var dbUpdater = new DbUpdateManager(_db);

            // Update online files.
            var ready = new List<VideoFile>();
            IEnumerable<VideoFile> queue = _db.VideoFiles.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos)
                .Where(x => x.Id > minId).ToList();

            var online = queue.Where(x => (new IsOnlineVideoAttribute()).HasAttribute(x.Type)).ToList();
            foreach (var item in online)
                dbUpdater.Convert(item);

            return Ok();
        }

        [HttpGet]
        [Route("convertChild")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public void Convert()
        {
            var dbUpdater = new DbUpdateManager(_db);
            var childMovies = _db.VideoFiles.Where(x => x.Type == VideoType.ChildEpisode || x.Type == VideoType.Animation || x.Type == VideoType.FairyTale);

            var convert = childMovies.Where(x => !x.Path.EndsWith("mp4") && !x.Path.EndsWith(".m4v")).ToList();

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
        [Route("updateFileCover/{fileId}/{coverUrl}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult> UpdateFileCover(int fileId, string coverUrl)
        {
            coverUrl = System.Web.HttpUtility.UrlDecode(coverUrl);
            var files = _db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).FirstOrDefault(x => x.Id == fileId);

            files.VideoFileExtendedInfo.Cover = RuTrackerUpdater.GetCoverByUrl(coverUrl);
            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("clearAll")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public void ClearFiles()
        {
            var files = _db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).ToList();

            foreach (var file in files.Where(x => x.Id > 5071))
            {
                Remove(file);
            }

            foreach (var file in files)
            {
                if ((!System.IO.File.Exists(file.Path) && !file.IsDownloading)|| 
                    file.Path.EndsWith(".srt") || file.Path.EndsWith(".mp3") || file.Path.EndsWith(".ac3") || file.Path.EndsWith(".dts") )
                    Remove(file);
            }

            var groupd = files.GroupBy(x => x.Path);
            foreach (var group in groupd.Where(x => x.Count() > 1))
            {
                var list = group.ToList();
                if (list[0].SeasonId == list[1].SeasonId && list[0].SeriesId == list[1].SeriesId)
                    Remove(list[1]);
            }

            _db.SaveChanges();
        }

        [HttpGet]
        [Route("updateCoverByFile")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateCoverByFile(int startId, int endId)
        {
            var dbUpdater = new DbUpdateManager(_db);

            var filesToUpdate = _db.VideoFiles.Where(x => x.Id >= startId && x.Id < endId).ToList();

            foreach (var file in filesToUpdate)
            {
                DbUpdateManager.FillVideoProperties(file);
                await _db.SaveChangesAsync();
            }

            return Ok();
        }

        [HttpGet]
        [Route("updateAll")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateAll()
        {
            var dbUpdater = new DbUpdateManager(_db);

            //// Update online files.
            //var ready = new List<VideoFile>();
            //IEnumerable<VideoFile> queue = _db.VideoFiles.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfo)
            //    .Where(x => x.Id > 19812).ToList();

            //foreach (var item in queue)
            //{
            //    item.SeriesId = 2038;
            //}
            ////_db.SaveChanges();

            //Test(dbUpdater, 19816);
            //Test(dbUpdater, 19813);
            //Test(dbUpdater, 8307);

            //var fairy = _db.VideoFiles.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfo)
            //    .Where(x => x.Id > 19816 && x.Id < 99999).ToList();
            //foreach (var item in fairy)
            //{
            //    item.Type = VideoType.Art;
            //}
            //_db.SaveChanges();


            //var season = _db.Seasons
            //    .Where(x => x.Id > 5370 && x.Id < 65370).ToList();
            //foreach (var item in season)
            //{
            //    _db.Remove(item);
            //}
            //_db.SaveChanges();

            ////var online = queue.Where(x => (new IsOnlineVideoAttribute()).HasAttribute(x.Type)).ToList();
            ////foreach (var item in online)
            ////    dbUpdater.Convert(item);

            //await MoveToSeason(20823, 20825, 5370, 2038, null, "Ромео и Джульетта");



            ////_db.SaveChanges();

            //dbUpdater.FillSeries(@"F:\Анюта\Мульты\Мультсериалы российские", Origin.Russian, VideoType.ChildEpisode, true);
            //dbUpdater.FillSeries(@"F:\Анюта\Фильмы\В гостях у сказки", Origin.Soviet, VideoType.FairyTale, false);

            //dbUpdater.FillSeries(@"F:\Анюта\Мульты\Советские мультфильмы\Солянка", Origin.Soviet, VideoType.Animation, false);
            //dbUpdater.FillSeries(@"F:\Анюта\Мульты\Советские мультфильмы\Известные", Origin.Soviet, VideoType.Animation, false);
            //dbUpdater.FillSeries(@"F:\Анюта\Мульты\Советские мультфильмы\Мультсериалы", Origin.Soviet, VideoType.ChildEpisode, true, "Мультсериалы");

            //dbUpdater.FillByRutrackerDownload(@"F:\Видео\Фильмы\Загрузки");
            //await UpdateByExistingRutracker(false);
            //dbUpdater.UpdateChildRutracker(@"F:\Видео\Фильмы\Загрузки");

            //// Courses
            //RemoveSeries(dbUpdater, 23);
            //dbUpdater.FillSeries(@"F:\Видео\Курсы\Видео", Origin.Russian, VideoType.Courses, false, "Видео");
            //dbUpdater.FillSeries(@"F:\Видео\Курсы\IT", Origin.Foreign, VideoType.Courses, false, "IT");

            // Get cover from Tg 
            //var tg = _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<TgBot>();
            //var filesToUpdateCoverByTg = _db.VideoFiles.Where(x => x.Type == VideoType.Animation && x.Origin != Origin.Soviet)
            //    .Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfo).OrderByDescending(x => x.Id).ToList();
            //filesToUpdateCoverByTg = filesToUpdateCoverByTg.Where(x => x.Cover == null || x.Cover.Length < 10 * 1024).ToList();
            //foreach (var file in filesToUpdateCoverByTg.Take(10))
            //    await tg.SearchImageForFile(file, 176280269);

            //Get cover from file
            //var filesToUpdateCover = _db.VideoFiles.Where(x => x.Type == VideoType.ChildEpisode || x.Type == VideoType.Courses || x.Origin == Origin.Soviet)
            //   .Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfo).ToList();
            //filesToUpdateCover = filesToUpdateCover.Where(x => x.Cover == null).ToList();
            //foreach (var file in filesToUpdateCover.Where(x => x.Cover == null))
            //    DbUpdateManager.FillVideoProperties(file);
            ////Parallel.ForEach(filesToUpdateCover, file => DbUpdateManager.FillVideoProperties(file));
            //_db.SaveChanges();

            //// Convert 
            //var cartoons = _db.VideoFiles.Where(x => x.Type == VideoType.Animation && x.Origin != Origin.Soviet);
            //foreach (var file in cartoons)
            //    dbUpdater.Convert(file);

            ////var courseFiles = _db.VideoFiles.Where(x => x.Type == VideoType.Courses);
            ////foreach (var file in courseFiles)
            ////    dbUpdater.Convert(file);

            return Ok();
        }

        private void Test(DbUpdateManager dbUpdater, int id)
        {
            var file = _db.VideoFiles.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).First(x => x.Id == id);
            var serie = _db.Series.First(x => x.Id == file.SeriesId);
            var season2 = dbUpdater.AddOrUpdateSeason(serie, file.Name);
            file.Season = season2;
            _db.SaveChanges();
        }

        [HttpGet]
        [Route("stub")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task Stub()
        {
            // To prevent server shutdown;
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
            dbUpdater.FillSeries(@"F:\Видео\Балет", Origin.Russian, VideoType.Art, false);
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
            }

            _db.SaveChanges();

            //_db.Series.Add(new Series { Name = "Просто фильмы", Type = VideoType.Film });
            //_db.Series.Add(new Series { Name = "Ликбез", Type = VideoType.Film });
        }

        private void RemoveSeries(DbUpdateManager dbUpdater, int serieId)
        {
            var files = _db.Files.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).Where(x => x.SeriesId == serieId).ToList();

            var manager = new DbUpdateManager(_db);

            foreach (var file in files)
                manager.RemoveFileCompletely(file);

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

    }
#endif
}