﻿using System.Collections.Generic;
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
using FileStore.Domain;
using Telegram.Bot.Types;
using System;
using System.Runtime;
using System.Security.AccessControl;
using System.Diagnostics;
using System.Xml.Serialization;
using TL;
using Microsoft.AspNetCore.Identity;
using FileStore.Infrastructure.Repositories;
using VkNet.Model;
using API.TG;

namespace FileStore.API.Controllers
{
#if DEBUG
    [EnableCors("CorsPolicy")]
    [AllowAnonymous]
    [Route("api/[controller]")]
    public class UpdateController : MainController
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly TgBot _tgBot;
        private  VideoCatalogDbContext _db;
        private readonly AppConfig _config;
        private readonly IServiceScopeFactory _serviceScopeFactory;

        [HttpGet]
        [Route("updateAll")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateAll()
        {
            await MoveToCurrentFolder();

            //var dbManager = new DbUpdateManager(_db);

            //RemoveSeasons(14940, 14967, true);

            //string log = null;
            //var files = _db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).ToList();
            //foreach (var file in files)
            //{
            //    if ((!System.IO.File.Exists(file.Path) && !file.IsDownloading))
            //    {
            //        dbManager.RemoveFileCompletely(file);
            //        log += file.Path + Environment.NewLine;
            //    }
            //}
            //_db.SaveChanges();

            //IEnumerable<VideoFile> queue = _db.VideoFiles.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos)
            //    .Where(x => x.Id > 1 && !x.NeedToDelete && !x.IsDownloading).ToList();

            //var online = queue.Where(x => (new IsOnlineVideoAttribute()).HasAttribute(x.Type) && !x.Path.EndsWith("mp4") && !x.Path.EndsWith("webm")).ToList();
            //foreach (var item in online)
            //    dbManager.Convert(item);

            //dbManager.AddAudioFilesFromFolder(@"D:\VideoServer\Аудио\Александр Пушкин - Евгений Онегин (Смоктуновский)", AudioType.AudioBook, Origin.Russian, false);
            //dbManager.AddAudioFilesFromFolder(@"D:\VideoServer\Аудио\Александр Пушкин - История Пугачёвского бунта", AudioType.AudioBook, Origin.Russian, false);
            //dbManager.AddAudioFilesFromFolder(@"D:\VideoServer\Аудио\Джек Лондон - Зов предков (Литвинов)", AudioType.AudioBook, Origin.Foreign, false);
            //dbManager.AddAudioFilesFromFolder(@"D:\VideoServer\Аудио\Терри Пратчетт - Ночная стража (Макс Потёмкин)", AudioType.AudioBook, Origin.Foreign, false);
            //dbManager.AddAudioFilesFromFolder(@"D:\VideoServer\Аудио\Терри Пратчетт - Патриот (Макс Потёмкин)", AudioType.AudioBook, Origin.Foreign, false);

            return Ok();
        }

        private async Task MoveToCurrentFolder()
        {
            var files = _db.Files.Include(x => x.VideoFileExtendedInfo).Where(x => !x.IsDownloading);
            var torrentManager = _serviceScopeFactory.CreateScope().ServiceProvider.GetService<IRuTrackerUpdater>();
            foreach (var file in files)
            {
                var fi = new FileInfo(file.Path);
                await torrentManager.MoveTorrent(file.VideoFileExtendedInfo.RutrackerId, fi.Directory.FullName);

            }
        }

        [HttpGet]
        [Route("updateSeasonFileTypeToSeries")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateFileTypesBySeries(int seasonId)
        {
            var season = _db.Seasons.First(x => x.Id == seasonId);
            var series = _db.Series.First(x => x.Id == season.SeriesId);

            if (series.Type != null)
            {
                var videos = _db.VideoFiles.Where(x => x.SeasonId == seasonId);
                foreach (var file in videos)
                {
                    file.SeriesId = series.Id;
                    file.Type = series.Type.Value;
                }
            }
            else
            {
                var audios = _db.AudioFiles.Where(x => x.SeasonId == seasonId);
                foreach (var file in audios)
                {
                    file.SeriesId = series.Id;
                    file.Type = series.AudioType.Value;
                }
            }

            _db.SaveChanges();

            return Ok();
        }

        public UpdateController(VideoCatalogDbContext dbContext, AppConfig config, 
            IServiceScopeFactory serviceScopeFactory, TgBot tgBot, UserManager<ApplicationUser> userManager)
        {
            _userManager = userManager;
            _tgBot = tgBot;
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
                if (!System.IO.File.Exists(file.Path))
                    _db.VideoFiles.Remove(file);
            }

            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("updateByRutrackersId")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateByRutrackerId()
        {
            var manager = new DbUpdateManager(_db);
            //await DeleteByRutrackerId(manager, "5754671");
            //await DeleteByRutrackerId(manager, "3903715");
            //await DeleteByRutrackerId(manager, "1460651");
            //await DeleteByRutrackerId(manager, "5565233");
            //await DeleteByRutrackerId(manager, "899612");
            //await DeleteByRutrackerId(manager, "1011059");
            //await DeleteByRutrackerId(manager, "5754671");
            //await DeleteByRutrackerId(manager, "3903715");
            //await DeleteByRutrackerId(manager, "5754671");
            //await DeleteByRutrackerId(manager, "3903715");
            //await DeleteByRutrackerId(manager, "6352695");
            //await DeleteByRutrackerId(manager, "4521111");
            //await DeleteByRutrackerId(manager, "2773613");
            //await DeleteByRutrackerId(manager, "6342215");
            //await DeleteByRutrackerId(manager, "6194960");
            //await DeleteByRutrackerId(manager, "4839320");
            //await DeleteByRutrackerId(manager, "6091735");
            //await DeleteByRutrackerId(manager, "6194960");
            //await DeleteByRutrackerId(manager, "6091735");
            //await DeleteByRutrackerId(manager, "3138942");
            //await DeleteByRutrackerId(manager, "3229867");
            //await DeleteByRutrackerId(manager, "4318473");
            //await DeleteByRutrackerId(manager, "5740721");
            //await DeleteByRutrackerId(manager, "2734135");

            //await RedownloadByRutrackerId(4854194);
            //await RedownloadByRutrackerId(3749082);
            //await RedownloadByRutrackerId(4854194);
            //await RedownloadByRutrackerId(4874327);
            //await RedownloadByRutrackerId(4290104);
            //await RedownloadByRutrackerId(3328876);
            //await RedownloadByRutrackerId(5138578);
            //await RedownloadByRutrackerId(798343);
            //await RedownloadByRutrackerId(5771745);
            //await RedownloadByRutrackerId(2081581);

            //await RedownloadByRutrackerId(3729674);
            //await RedownloadByRutrackerId(3283453);

            await RedownloadByRutrackerId(2801702);
            await RedownloadByRutrackerId(4839067);
            await RedownloadByRutrackerId(3453597);
            await RedownloadByRutrackerId(5741326);
            await RedownloadByRutrackerId(4655655);
            await RedownloadByRutrackerId(5742848);
            _db.SaveChanges();
            return Ok();
        }

        private async Task RedownloadByRutrackerId(int id)
        {
            var files = _db.Files.Where(x => x.Path.Contains(id.ToString()));

            foreach (var file in files)
            {
                //var directory = new DirectoryInfo(file.Path);

                //var path = directory.Parent.FullName;
                //if (Directory.Exists(path))
                //    Directory.Delete(path, true);

                //path = path.Replace("D:\\VideoServer\\Rutracker\\", "Z:\\VideoServer\\Rutracker");
                file.Path = @$"Z:\VideoServer\Rutracker\{id}";
                file.IsDownloading = true;
                await AddTorrent(id, file.Path);
            }
        }

        private async Task DeleteByRutrackerId(DbUpdateManager manager, string v)
        {
            var files = _db.Files.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos)
                .Where(x => x.Path.Contains(v)).ToList();

            if (files.Count() > 1)
            {

            }

            foreach (var file in files)
            {
                try
                {
                    file.VideoFileUserInfos.ToList().ForEach(x => _db.FilesUserInfo.Remove(x));
                    _db.FilesInfo.Remove(file.VideoFileExtendedInfo);
                    _db.Files.Remove(file);
                    _db.SaveChanges();

                    var _rutracker = new RuTrackerUpdater(_config);
                    await _rutracker.Init();
                    await _rutracker.DeleteTorrent(file.VideoFileExtendedInfo.RutrackerId.ToString());
                }
                catch (Exception ex)
                {
                }
            }
        }

        [HttpGet]
        [Route("syncDb")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> SyncDb()
        {
            var secondDb = VideoCatalogContextFactory.CreateSecondDb();

            var files = _db.VideoFiles.ToList();

            var oldFiles = secondDb.VideoFiles.ToList();

            var filesPairs = files.ToDictionary(x => x, x => oldFiles.FirstOrDefault(oldFile => oldFile.Id == x.Id));
            var differentTypes = filesPairs.Where(x => x.Key.Type !=x.Value?.Type).ToList();
            var wrongFIlms = differentTypes.Where(x => x.Key.Type == VideoType.Unknown);
            foreach (var file in differentTypes.Where(x => x.Key.Type== VideoType.Unknown))
            {
                file.Key.Type = VideoType.Film;
            }

            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("clearNonMP4")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> ClearNonMp4()
        {
            var directory = new DirectoryInfo(@"F:\Анюта\Советские мультфильмы");
            var files = directory.GetFiles("*.*", SearchOption.AllDirectories);

            var toDelete = files.Where(x => !x.Extension.EndsWith("mp4")).ToList();
            var good = files.Where(x => x.Extension.EndsWith("mp4")).ToList();

            if (good.Count != toDelete.Count)
                return Ok();

            foreach (var file in toDelete)
                System.IO.File.Delete(file.FullName);

            return Ok();
        }

        private async Task<string> TryToFindFile(string folder, string fullName)
        {
            var dirInfo = new DirectoryInfo(folder);

            //if (!dirInfo.Exists)
            //{
            //    await AddTorrent(folder, dirInfo);

            //    return null;
            //}

            try
            {
                var name = GetName(fullName);
                var goodFiles = dirInfo.GetFiles("*", SearchOption.AllDirectories).Where(x => GetName(x.FullName) == name);

                if (goodFiles.Any(x => x.Name.Contains(".mp4")))
                {
                    return null;
                }

                if (!goodFiles.Any())
                    return null;

                var found = goodFiles.OrderByDescending(x => x.Length).First();

                return found.FullName;
            }
            catch (Exception ex)
            {
                //await AddTorrent(folder, dirInfo);
            }

            return null;
        }

        private async Task AddTorrent(string folder, DirectoryInfo dirInfo)
        {
            await AddTorrent(int.Parse(dirInfo.Name), folder);
        }
        private async Task AddTorrent(int id, string folder)
        {
            try
            {
                var rutracker = new RuTrackerUpdater(_config);
                await rutracker.Init();
                await rutracker.DeleteTorrent(id.ToString());
                await rutracker.StartDownload(id, folder);
            }
            catch (Exception)
            {
            }
        }

        private string GetName(string fullName)
        {
            var fInfo = new FileInfo(fullName);

            var text = fInfo.Name;
            var qualityStart = text.LastIndexOf(".");
            if (qualityStart != -1)
                text = text.Substring(0, qualityStart);

            return text;
        }

        [HttpGet]
        [Route("moveSeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveSeason(int seasonId, int newSeriesId)
        {
            var season = _db.Seasons.FirstOrDefault(x => x.Id == seasonId);

            season.SeriesId = newSeriesId; 
            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("markComplete")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MarkComplete(int fileId, string filePath)
        {
            var file = _db.VideoFiles.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).
                FirstOrDefault(x => x.Id == fileId);

            file.IsDownloading = false;
            file.Path = filePath;

            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("moveToBalley")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveToBalley(int fileId)
        {
            var file = _db.VideoFiles.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).
                FirstOrDefault(x => x.Id == fileId);
            file.Type = VideoType.Art;

            var series = _db.Series.Where(x => x.Type == VideoType.Art);
            if (series.Count() > 1)
                series = series.Where(x => x.Name == "Балет");

            var season = new Season { Name = file.Name, SeriesId = series.First().Id };

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
        [Route("removeYoutube")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public void RemoveYoutube()
        {
            var series = _db.Series.FirstOrDefault(x => x.Name == "Youtube");

            if (series == null)
                return;

            RemoveSeries(new DbUpdateManager(_db), series.Id);
        }

        [HttpDelete]
        [Route("importFromDb")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public void ImportFromAnotherDb()
        {
            var optionsBuilder = new DbContextOptionsBuilder<VideoCatalogDbContext>();
            optionsBuilder.UseSqlServer("Server=localhost;Database=res;Encrypt=False;Trusted_Connection=True;");

            var extDb = new VideoCatalogDbContext(optionsBuilder.Options);

            var filesWithoutImage = _db.Files.Where(x => x.Cover == null);

            var ff = extDb.Files.ToList();
            var ff2 = _db.Files.ToList();
            var missing = ff.Where(x => !ff2.Any(y => y.Path == x.Path)).ToList();
            var str = string.Join(Environment.NewLine, missing.Select(x => x.Path));

            var files = extDb.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).Include(x => x.Season).
                Where(
                    x => x.Id >= missing[558].Id && x.Id <= missing[565].Id
                ).ToList();
            var str2 = string.Join(Environment.NewLine, files.Select(x => x.Path));

            var updateFiles = new List<VideoFile>();
            files.ToList().ForEach(x =>
            {
                if (!System.IO.File.Exists(x.Path))
                {
                    return;
                }
                updateFiles.Add(x);
                foreach (var item in x.VideoFileUserInfos)
                {
                    item.Id = 0;
                }
                x.VideoFileExtendedInfo.Id = 0;
                x.Id = 0;

                //var series = _db.Series.FirstOrDefault(serie => serie.Name == x.Series.Name);
                //if (series != null)
                //{
                //    x.SeriesId = series.Id;
                //    x.Series = null;
                //}
                //else
                //    x.SeriesId = 0;
                var season = _db.Seasons.FirstOrDefault(serie => serie.Name == x.Season.Name);
                if (season != null)
                {
                    x.SeasonId = season.Id;
                    x.Season = null;
                }
                else
                    x.SeasonId = 0;
            });

            _db.AddRange(updateFiles);
            _db.SaveChanges();
        }

        [HttpDelete]
        [Route("removeSeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public void RemoveSeason(int seasonId, bool physicallyDeleteFile)
        {
            var files = _db.Files.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).Where(x => x.SeasonId == seasonId).ToList();

            var manager = new DbUpdateManager(_db);
            foreach (var file in files)
            {
                manager.RemoveFileCompletely(file);

                if (physicallyDeleteFile)
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
        [Route("removeSeasons")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public void RemoveSeasons(int startSeasonId, int endSeasonId, bool physicallyDeleteFile)
        {
            for (int i = startSeasonId; i <= endSeasonId; i++)
            {
                try
                {
                    this.RemoveSeason(i, physicallyDeleteFile);
                }
                catch (Exception ex)
                {
                }
            }
        }

        [HttpDelete]
        [Route("removeManySeries")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> RemoveSeries(int startSerieId, int endSerieId, bool physicallyDeleteFile)
        {
            var dbManager = new DbUpdateManager(_db);
            for (int i = startSerieId; i < endSerieId; i++)
            {
                await DeleteSerie(i, physicallyDeleteFile, new DbUpdateManager(_db));
            }
            return Ok();
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

        [HttpDelete]
        [Route("removeSeveralFiles")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public void RemoveFiles() {


            this.RemoveFile(50841, true);
            this.RemoveFile(50843, true);
            this.RemoveFile(50845, true);
        }

        [HttpDelete]
        [Route("removeFile")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> RemoveFile(int fileId, bool deleteFile)
        {
            var file = _db.Files.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).First(x => x.Id == fileId);

            if (deleteFile)
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
        [Route("addManyYoutube")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> AddManyYoutube()
        {
            await this.AddFolder(@"F:\Видео\Курсы\IT", VideoType.Courses, true);
            await this.AddFolder(@"F:\Видео\Курсы\IT", VideoType.Courses, true);

            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=qmsrd9IVIh8", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=FC3AilGtb8M", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=ulN-85A6nko", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=n_twIi6l0dQ", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=iiKsyZeqtbo", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=sA2sctbdV6A", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=w_AsKtKnw3s", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=_Qbff14DEsc", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=EuB9E2iMavw", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=AZvWHdLcwOQ", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=49Qz_VvcKQk", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=1ZIaoP2tyO0", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=EgrjTiLe4_w", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=aI_47Kzb8WY", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=JJNccH7lNNM", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=-lRx_V1o_iQ", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=iLg1fkBh7Pw", 11, null, false);

            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=TKT5mmiPKeU", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=L4mUNieliHs", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=E02BsIhcAHQ", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=TgvAPr__YDg", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=A1VFD9OX-q0", 11, null, false);
            //await _tgBot.ProcessYoutubeVideo("https://www.youtube.com/watch?v=WwxBng1i5M0", 11, null, false);

            //await this.RemoveSeries(6093, false );
            //await this.AddFolder(@"F:\Видео\Курсы\IT", VideoType.Courses, true);

            return Ok();
        }

        [HttpGet]
        [Route("moveFileToSeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveFileToSeason(int fileId, int newSeasonId)
        {
            var season = _db.Seasons.Where(x => x.Id == newSeasonId).First();

            var file = _db.Files.FirstOrDefault(x => x.Id == fileId);
            file.SeasonId = season.Id;
            file.SeriesId = season.SeriesId;

            _db.SaveChanges();

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
                dbUpdater.AddSeries(path, type == VideoType.Courses ? Origin.Foreign : Origin.Russian, type.Value, severalSeriesInFolder, seriesName);
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

            dbUpdater.AddSeries(path, Origin.Soviet, type.Value, false, "Загрузки");

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

            var series = _db.Series.FirstOrDefault(x => x.Id == seriesId);
            _db.Remove(series);
            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("moveWholeSeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveWholeSeasons()
        {
            await MoveWholeSeason(13471, 13469);
            await MoveWholeSeason(13472, 13469);
            await MoveWholeSeason(13478, 13469);
            await MoveWholeSeason(13480, 13469);
            await MoveWholeSeason(13481, 13469);
            await MoveWholeSeason(13484, 13469);
            return Ok();
        }

        private async Task MoveWholeSeason(int oldSeasonId, int seasonId)
        {
            var files = _db.VideoFiles.Where(x => x.SeasonId == oldSeasonId).ToList();
            foreach (var file in files)
            {
                file.SeasonId = seasonId;
            }

            _db.SaveChanges();

            var season = _db.Seasons.First(x => x.Id == oldSeasonId);
            _db.Remove(season);
            _db.SaveChanges();
        }

        [HttpGet]
        [Route("moveToSeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveToSeason(int startId, int finishId, int seasonId, int seriesId = 0,
            VideoType? type = null, string seasonName = null)
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
        [Route("createUser")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> CreateUser(string login, string pass)
        {
            var managedUser = await _userManager.FindByNameAsync(login);
            if (managedUser != null)
               await  _userManager.DeleteAsync(managedUser);

            var user = new ApplicationUser { UserName = login };
            var createdUser = await _userManager.CreateAsync(user, pass);

            return Ok();
        }


        [HttpGet]
        [Route("reDownloadByRutracker")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> ReDownloadByRutracker()
        {
            _ReDownloadByRutracker(VideoType.Animation);
            _ReDownloadByRutracker(VideoType.FairyTale);
            return Ok();
        }

        private void _ReDownloadByRutracker(VideoType animation)
        {
            var files = _db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).
                Where(x => x.VideoFileExtendedInfo.RutrackerId != 0 && x.Type == animation).ToList();

            var rutracker = new RuTrackerUpdater(_config);
            var dbUpdater = new DbUpdateManager(_db);
            foreach (var file in files)
            {
                var directory = new DirectoryInfo(file.Path);
                var path = directory.Parent.FullName;
                //rutracker.StartDownload(file.VideoFileExtendedInfo.RutrackerId, path);

                //var dirInfo= new DirectoryInfo(path);
                //var dirFiles = dirInfo.GetFiles();

                ////foreach (var fileDBRecord in dir)
                //{
                //    var same = dirFiles;
                //    //var same = dirFiles.Where(x => x.Name == file.Name);
                //    if (same.Any())
                //    {
                //        var found = same.OrderByDescending(x => x.Length).First();
                //        var newPath = DbUpdateManager.EncodeToMp4(found.FullName);

                //        if (file.Path != newPath)
                //        {

                //        }
                //    }
                //}
            }

            throw new NotImplementedException();
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
                    var info = await _rutracker.FillVideoInfo(id);
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

            var info = await _rutracker.FillVideoInfo(file.VideoFileExtendedInfo.RutrackerId);
            _rutracker.FillFileInfo(file, info);

            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("removeAudioNameDuplicate")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> RemoveAudioNameDuplicate()
        {
            var duplicates = _db.Seasons.Where(x => x.Series.AudioType != null).ToList().GroupBy(x => x.Name);

            var removeSeason = new List<Season>();
            foreach (var duplicate in duplicates)
            {
                if (duplicate.Count() == 1)
                    continue;

                removeSeason.AddRange(duplicate.Skip(1));
            }

            var manager = new DbUpdateManager(_db);
            var fileRepo = new DbFileRepository(_db, null);
            var seriesRepo = new SeriesRepository(_db, fileRepo);

            foreach (var season in removeSeason)
            {
                await seriesRepo.RemoveSeasonById(season.Id);
            }

            await _db.SaveChangesAsync();

            var removeFiles = new List<DbFile>();
            var seasons = _db.Files.Where(x => x.Series.AudioType != null).ToList()
                .GroupBy(x => x.SeasonId);
            foreach (var season in seasons)
            {
                var duplicatesFiles = season.ToList().GroupBy(x => x.Name);

                foreach (var duplicate in duplicatesFiles)
                {
                    if (duplicate.Count() == 1)
                        continue;

                    removeFiles.AddRange(duplicate.Skip(1));
                }
            }

            foreach (var season in removeFiles)
            {
                fileRepo.RemoveFileCompletely(season.Id);
            }

            await _db.SaveChangesAsync();


            return Ok();
        }

        [HttpGet]
        [Route("removeDuplicate")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> RemoveDuplicate()
        {
            var dbUpdater = new DbUpdateManager(_db);

            var files = _db.Files.ToList();

            var duplicates = files.GroupBy(x => x.Path);

            var filesToRemove = new List<DbFile>();

            foreach (var duplicate in duplicates)
            {
                if (duplicate.Count() == 1)
                    continue;

                var toDelete = duplicate.Skip(1);
                foreach (var file in toDelete)
                {
                    Remove(file);
                    //_db.Files.Remove(file);
                }

                filesToRemove.AddRange(toDelete);
            }
            var str = string.Join(Environment.NewLine, filesToRemove);

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
        [Route("updateEpisodesName")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateEpisodesName(int seriesId)
        {
            var serie = _db.Series.Include(x => x.Seasons).ThenInclude(x => x.Files).First(x => x.Id == seriesId);
            foreach (var season in serie.Seasons)
            {
                var startNumber = season.Files.First().Number - 1;
                foreach (var file in season.Files)
                {
                    file.Name = $"{season.Name} - {file.Number - startNumber}";
                }
            }

            _db.SaveChanges();

            return Ok();
        }

        [HttpGet]
        [Route("convertToAnotherPlace")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> ConvertToAnotherPlace()
        {
            ////await ConvertToAnotherPlace(@"Z:\Smth\Bittorrent\СВ\Суд времени\Кургинян");
            // await ConvertNewOnline();

            //await ConvertToAnotherPlace(@"Z:\Smth\Bittorrent\СВ\Школа сути\Школа сути");
            //await ConvertToAnotherPlace(@"Z:\Smth\Bittorrent\СВ\СВ\Суть времени (ЭТЦ), 2011");

            //ImportEoT("F:\\Видео\\СВ\\Суд времени", true);
            //ImportEoT("F:\\Видео\\СВ\\Суть времени", false);
            ImportEoT("F:\\Видео\\СВ\\Школа сути", false);
            //RemoveSeries(6112, false);

            return Ok();
        }

        private void ImportEoT(string pathv, bool haveSubdir)
        {
            var directoryInfo = new DirectoryInfo(pathv);
            if (haveSubdir)
            {
                foreach (var subDir in directoryInfo.GetDirectories())
                    ClearSmallerDir(subDir);
            }
            else
                ClearSmallerDir(directoryInfo);

            var dbupdater = new DbUpdateManager(_db);
            dbupdater.AddSeries(pathv, Origin.Russian, VideoType.EoT, false);
            RemoveSeries(6114, false);
        }

        private void ClearSmallerDir(DirectoryInfo subDir)
        {
            var files = subDir.GetFiles("*.*");

            var originalFiles = files.Where(x => !x.Name.Contains('(')).ToList();
            var convertedFiles = files.Where(x => x.Name.Contains('(')).ToList();
            foreach (var original in originalFiles)
            {
                var converted = convertedFiles.FirstOrDefault(x => x.Name.Substring(0, 1) == original.Name.Substring(0, 1));
                if (converted == null)
                {

                }
                else
                {
                    original.Delete();
                }
            }

        }


        private static string GetDestinationPath(string newFIle)
        {
            var newPath = newFIle.Replace(@"Z:\Smth\Bittorrent\СВ\Суд времени\Кургинян", @"F:\Видео\СВ\Суд времени");
            newPath = newPath.Replace(@"Z:\Smth\Bittorrent\СВ\СВ\Суть времени (ЭТЦ), 2011", @"F:\Видео\СВ\Суть времени");
            newPath = newPath.Replace(@"Z:\Smth\Bittorrent\СВ\Школа сути\Школа сути", @"F:\Видео\СВ\Школа сути");
            return newPath;
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
                    VideoHelper.ChangeQuality(file, newFolder, FFMpegCore.Enums.VideoSize.Hd);
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

            files.SetCover(RutrackerInfoParser.GetCoverByUrl(coverUrl));
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
        [Route("moveSeasonToNewType")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MovestartSeasonToNewType(string seriesName, int startSeasonId, int endSeasonId)
        {
            var dbUpdater = new DbUpdateManager(_db);

            var series = dbUpdater.AddOrGetSeries(seriesName, false, false);
            _db.SaveChanges();
            series.Type = VideoType.Special;

            var seasonIds = _db.Seasons.Where(x => x.Id>=startSeasonId && x.Id <= endSeasonId).Select(x => x.Id).ToList();

            foreach (var seasonId in seasonIds)
                _MoveSeasonToSpecial(seasonId, series.Id);

            return Ok();
        }

        private void _MoveSeasonToSpecial(int seasonId, int seriesId)
        {
            var season = _db.Seasons.Include(x => x.Files).FirstOrDefault(x => x.Id == seasonId);
            foreach (var file in season.Files)
            {
                file.SeriesId = seriesId;
            }
            season.SeriesId = seriesId;
            _db.SaveChanges();
        }

        [HttpGet]
        [Route("removeEmptySeasons")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> RemoveEmptySeasons()
        {
            //var series = _db.Series.Where(x => !x.Files.Any()).ToList();
            //foreach (var serie in series)
            //{
            //    await RemoveSeries(serie.Id, false);
            //}

            var seasons = _db.Seasons.Where(x => !x.Files.Any()).ToList();
            foreach (var serie in seasons)
            {
                 RemoveSeason(serie.Id, false);
            }

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
            dbUpdater.AddSeries(@"F:\Видео\Балет", Origin.Russian, VideoType.Art, false);
            dbUpdater.AddSeries(@"F:\Видео\Фильмы", Origin.Unknown, VideoType.Film, true);

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