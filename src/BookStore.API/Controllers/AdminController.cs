using System.Linq;
using System.Threading.Tasks;
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
using FileStore.Domain;
using Microsoft.AspNetCore.Identity;
using System.IO;
using System.Collections.Generic;
using API.Controllers;
using API.TG;
using System;
using TL;
using AngleSharp.Io;
using Microsoft.Identity.Client;
using Infrastructure.Scheduler;

namespace FileStore.API.Controllers
{
#if DEBUG
    [EnableCors("CorsPolicy")]
    [AllowAnonymous]
    [Route("api/[controller]")]
    public class AdminController : MainController
    {
        private  VideoCatalogDbContext _db;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly TgBot _tgBot;
        private readonly AppConfig _config;
        private readonly IServiceScopeFactory _serviceScopeFactory;

        public AdminController(VideoCatalogDbContext dbContext, AppConfig config, 
            IServiceScopeFactory serviceScopeFactory, TgBot tgBot, UserManager<ApplicationUser> userManager)
        {
            _userManager = userManager;
            _tgBot = tgBot;
            _db = dbContext;
            _config = config;
            _serviceScopeFactory = serviceScopeFactory;
        }

        [HttpGet]
        [Route("doAction")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> DoAction()
        {
            RemoveFile(54671, true);
            //await CombineSeasons("Сказки на ночь, которые помогут малышам спокойно заснуть", 15007, 15021);

            //CreateSeason("Списки", "Список Жаринова", 54656, 54658, false);
            //CreateSeason("Списки", "Список Жаринова", 54651, 54651, false);
            //CreateSeason("Списки", "Список Жаринова", 54642, 54648, false);

            //var filesList = "";
            //var ids = new List<int>();
            //foreach (var file in _db.Files.ToList())
            //{
            //    if (!System.IO.File.Exists(file.Path))
            //    {
            //        filesList += Environment.NewLine + file.Path;
            //        ids.Add(file.Id);
            //    }
            //}
            //// Move not converted.
            //var fileManager = new FileManager(_db, new FileManagerSettings(_config.RootFolder, _config.RootDownloadFolder, false));
            //var manager = new FileManager(_db, new FileManagerSettings());
            //var filesToConvert = _db.VideoFiles.ToList().Where(x => VideoHelper.ShouldConvert(x as VideoFile)).ToList();
            //foreach (var file in filesToConvert)
            //    await fileManager.MoveFile(file);

            // Get Fairy tales
            //var tgAPI = _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<TgAPIClient>();
            //await tgAPI.ImportMessages();

            // Add courses
            //var dbUpdater = new DbUpdateManager(_db);
            //await dbUpdater.AddAllCourcesFromFolder(@"C:\Users\Dim\Documents\Курсы", _config);

            // TODO - move for rutracker
            //var files = db.VideoFiles.Where(x => x.Path.Contains(@"D:\VideoServer\")).Include(x => x.VideoFileExtendedInfo).ToList();
            //var rutrackerIds = files.GroupBy(x => x.VideoFileExtendedInfo.RutrackerId);
            //foreach (var item in rutrackerIds)
            //{
            //    await MoveFileInRutracker(db, torrentManager, item.First());
            //}


            return Ok();
        }

        [HttpDelete]
        [Route("removeFile")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> RemoveFile(int fileId, bool deleteFile)
        {
            var file = _db.Files.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).First(x => x.Id == fileId);

            if (deleteFile)
                await PhisicallyRemoveFile(file);

            var manager = new DbUpdateManager(_db);
            manager.RemoveFileCompletely(file);

            _db.SaveChanges();

            return Ok();
        }

        [HttpDelete]
        [Route("removeSeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public void RemoveSeason(int seasonId, bool physicallyDeleteFile)
        {
            var files = _db.Files
                .Include(x => x.VideoFileUserInfos)
                .Include(x => x.VideoFileExtendedInfo)
                .Where(x => x.SeasonId == seasonId).ToList();

            var manager = new DbUpdateManager(_db);
            foreach (var file in files)
            {
                manager.RemoveFileCompletely(file);

                if (physicallyDeleteFile)
                    System.IO.File.Delete(file.Path);
            }

            var season = _db.Seasons.First(x => x.Id == seasonId);
            _db.Seasons.Remove(season);
            if (!_db.Seasons.Any(x => x.SeriesId == season.SeriesId))
            {
                var serie = _db.Series.First(x => x.Id == season.SeriesId);
                _db.Series.Remove(serie);
            }

            _db.SaveChanges();
        }

        [HttpGet]
        [Route("combineSeasons")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> CombineSeasons(string seasonName, int firstId, int secondId)
        {
            var manager = new DbUpdateManager(_db);

            var season = _db.Seasons.FirstOrDefault(x => x.Id == firstId);

            var files = _db.Files.Where(x => x.SeasonId == secondId).ToList();
            foreach (var item in files)
            {
                item.SeriesId = season.SeriesId;
                item.SeasonId = season.Id;
            }

            season.Name = seasonName;

            var secondSeason = _db.Seasons.FirstOrDefault(x => x.Id == secondId);
            _db.Seasons.Remove(secondSeason);

            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("createVideoSeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> CreateSeason(string seriesName, string seasonName, int startId, int finishId, bool isChild)
        {
            var manager = new DbUpdateManager(_db);

            var files = _db.VideoFiles.Where(x => x.Id >= startId && x.Id <= finishId).ToList();

            var series = manager.AddOrUpdateSeries(seriesName, false, isChild);
            series.Type = files.FirstOrDefault().Type;
            var season = manager.AddOrUpdateSeason(series, seasonName);
            foreach (var item in files)
            {
                item.SeriesId = series.Id;
                item.SeasonId = season.Id;
            }

            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("convertOnline")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> ConvertNewOnline(int minId = 48354)
        {
            var dbUpdater = new DbUpdateManager(_db);

            IEnumerable<VideoFile> queue = _db.VideoFiles.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos)
                .Where(x => x.Id > minId && !x.NeedToDelete && !x.IsDownloading).ToList();

            var online = queue.Where(x => (new IsOnlineVideoAttribute()).HasAttribute(x.Type) && !x.Path.EndsWith("mp4") && !x.Path.EndsWith("webm")).ToList();
            foreach (var item in online)
                dbUpdater.Convert(item, _config);

            return Ok();
        }

        [HttpDelete]
        [Route("clearAll")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public void ClearFiles()
        {
            var manager = new DbUpdateManager(_db);

            var files = _db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).ToList();
            foreach (var file in files)
            {
                if ((!System.IO.File.Exists(file.Path) && !file.IsDownloading))
                    manager.RemoveFileCompletely(file);
            }

            _db.SaveChanges();
        }

        [HttpDelete]
        [Route("removeSeries")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> RemoveSeries(int serieId, bool deleteFile)
        {
            var dbManager = new DbUpdateManager(_db);

            await DeleteSerie(serieId, deleteFile, dbManager);

            return Ok();
        }

        private async Task DeleteSerie(int serieId, bool deleteFile, DbUpdateManager dbManager)
        {
            if (deleteFile)
            {
                var files = _db.Files.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).
                    Where(x => x.SeriesId == serieId).ToList();
                foreach (var file in files)
                {
                    if (deleteFile)
                        await PhisicallyRemoveFile(file);
                }
            }
            dbManager.RemoveSeriesCompletely(serieId);
        }

        [HttpGet]
        [Route("addVideoFolder")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> AddVideoFolder(string path, VideoType? type = null, bool severalSeriesInFolder = false, string seriesName = null)
        {
            var dbUpdater = new DbUpdateManager(_db);

            if (type == VideoType.ChildEpisode || type == VideoType.Courses)
            {
                dbUpdater.AddSeries(path, type == VideoType.Courses ? Origin.Foreign : Origin.Russian, type.Value, severalSeriesInFolder, seriesName);
                return Ok();
            }

            return NotFound();
        }

        [HttpGet]
        [Route("addAudioFolder")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> AddAudioFolder(string path, AudioType type, bool severalSeriesInFolder = false, string bookTitle = null)
        {
            var dbUpdater = new DbUpdateManager(_db);

            dbUpdater.AddAudioFilesFromFolder(path, type, Origin.Unknown, severalSeriesInFolder, bookTitle);
            return Ok();
        }

        [HttpGet]
        [Route("updateFileInfo")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateCoverByFile(int startId, int endId)
        {
            var dbUpdater = new DbUpdateManager(_db);

            var filesToUpdate = _db.VideoFiles.Where(x => x.Id >= startId && x.Id <= endId).ToList();

            foreach (var file in filesToUpdate)
            {
                VideoHelper.FillVideoProperties(file);
                await _db.SaveChangesAsync();
            }

            return Ok();
        }

        [HttpGet]
        [Route("convertFile")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public void ConvertFile(int fileId)
        {
            var dbUpdater = new DbUpdateManager(_db);
            var file = _db.VideoFiles.First(x => x.Id == fileId);

            dbUpdater.Convert(file, _config, true);
        }

        [HttpGet]
        [Route("updateFileByYoutube")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveSeason(int fileId, string youtubeLink)
        {
            var file = _db.Files.FirstOrDefault(x => x.Id == fileId);

            var fInfo = new FileInfo(file.Path);
            var newfInfo = new FileInfo(fInfo.FullName.Replace(fInfo.Name, $"youtube_{fInfo.Name}"));

            var downloader = DownloaderFabric.CreateDownloader(youtubeLink, _config);
            var filePath = await downloader.Download(youtubeLink, newfInfo.FullName);

            var newFileName = $"{filePath}#.mp4";
            if (!System.IO.File.Exists(newFileName))
                return BadRequest();

            file.Path = newFileName;
            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("moveSeasonToAnotherSeries")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveSeason(int seasonId, int newSeriesId)
        {
            var season = _db.Seasons.FirstOrDefault(x => x.Id == seasonId);
            var newSeries = _db.Series.First(x => x.Id == season.SeriesId);

            MoveFilesToNewSeasonSeries(seasonId, season.Id, newSeries);

            season.SeriesId = newSeriesId;

            var oldSeries = _db.Series.FirstOrDefault(x => x.Id == seasonId);
            _db.Remove(oldSeries);
            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("moveFileToSeasonByName")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveFileToSeasonByName(int fileId, string seasonName, string seriesName, VideoType type)
        {
            var dbUpdater = new DbUpdateManager(_db);
            var series = dbUpdater.AddOrUpdateVideoSeries(seriesName, false, type);
            var season = dbUpdater.AddOrUpdateSeason(series.Id, seasonName);

            if(series.Type != null)
            {
                var file = _db.VideoFiles.FirstOrDefault(x => x.Id == fileId);
                file.SeasonId = season.Id;
                file.SeriesId = season.SeriesId;
                file.Type = type;
            }
            else
            {
                var file = _db.AudioFiles.FirstOrDefault(x => x.Id == fileId);
                file.SeasonId = season.Id;
                file.SeriesId = season.SeriesId;
                file.Type = series.AudioType.Value;
            }

            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("moveSeasonFilesToAnotherSeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveToSeason(int oldSeasonId, int newSeasonId)
        {
            var newSeason = _db.Seasons.First(x => x.Id == newSeasonId);
            var newSeries = _db.Series.First(x => x.Id == newSeason.SeriesId);

            MoveFilesToNewSeasonSeries(oldSeasonId, newSeasonId, newSeries);

            var oldSeason = _db.Seasons.First(x => x.Id == oldSeasonId);
            _db.Seasons.Remove(oldSeason);
            _db.SaveChanges();

            return Ok();
        }

        private void MoveFilesToNewSeasonSeries(int oldSeasonId, int newSeasonId, Series newSeries)
        {
            if (newSeries.Type != null)
            {
                var videos = _db.VideoFiles.Where(x => x.SeasonId == oldSeasonId);
                foreach (var file in videos)
                {
                    file.SeasonId = newSeasonId;
                    file.SeriesId = newSeries.Id;
                    file.Type = newSeries.Type.Value;
                }
            }
            else
            {
                var audios = _db.AudioFiles.Where(x => x.SeasonId == oldSeasonId);
                foreach (var file in audios)
                {
                    file.SeasonId = newSeasonId;
                    file.SeriesId = newSeries.Id;
                    file.Type = newSeries.AudioType.Value;
                }
            }
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
                if(System.IO.File.Exists(file.Path))
                    System.IO.File.Delete(file.Path);
        }

        [HttpGet]
        [Route("moveSeriesFilesToAnother")]
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

            var series = _db.Series.FirstOrDefault(x => x.Id == seriesId);
            _db.Remove(series);
            _db.SaveChanges();

            return Ok();
        }
    }
#endif
}