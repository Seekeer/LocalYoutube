using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using FileStore.API.Dtos.File;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Infrastructure;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace FileStore.API.Controllers
{
    [EnableCors()]
    [Route("api/[controller]")]
    public class FilesController : MainController
    {
        private readonly IFileService _FileService;
        private readonly VideoCatalogDbContext _db;
        private readonly IMapper _mapper;
        private readonly static Dictionary<string, int> _randomFileDict = new Dictionary<string, int>();

        public FilesController(IMapper mapper, IFileService FileService, VideoCatalogDbContext dbContext)
        {
            _mapper = mapper;
            _FileService = FileService;
            _db = dbContext;
        }

        [HttpGet]
        [Route("updateAll")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> UpdateAll()
        {
            var dbUpdater = new DbUpdateManager(_db);

            //var films = _db.Files.Include(x => x.VideoFileExtendedInfo).Where(x => x.SeriesId == 11).ToList();
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
            //    if (file.VideoFileUserInfo == null)
            //        file.VideoFileUserInfo = new VideoFileUserInfo();
            //}
            //_db.SaveChanges();


            //dbUpdater.FillSeries(@"D:\Мульты\YandexDisk\Анюта\Советские мультфильмы\Мультсериалы", Origin.Soviet, VideoType.Episode);
            //dbUpdater.FillFilms(@"D:\Мульты\YandexDisk\Анюта\Фильмы-Сказки", Origin.Soviet, VideoType.FairyTale);

            return Ok();
        }

        private void Convert(DbUpdateManager dbUpdater)
        {
            var mp4Count = _db.VideoFiles.Count(x => !x.Path.EndsWith("mp4"));
            var totalCount = _db.VideoFiles.Count();

            var convert = _db.VideoFiles.Where(x => !x.Path.EndsWith("mp4")).ToList();
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
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAll()
        {
            var Files = await _FileService.GetAll();

            return Ok(_mapper.Map<IEnumerable<VideoFileResultDto>>(Files));
        }

        [HttpGet("{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetById(int id)
        {
            var File = await _FileService.GetById(id);

            if (File == null) return NotFound();

            return Ok(_mapper.Map<VideoFileResultDto>(File));
        }

        [HttpGet]
        [Route("getFilesBySeries")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetFilesBySeries(int id, int count, bool isRandom)
        {
            var Files = await _FileService.GetFilesBySearies(id, isRandom);

            if (!Files.Any()) 
                return NotFound();

            return Ok(_mapper.Map<IEnumerable<VideoFileResultDto>>(Files));
        }

        [HttpPost]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> Add(FileAddDto FileDto)
        {
            if (!ModelState.IsValid) return BadRequest();

            var File = _mapper.Map<VideoFile>(FileDto);
            var FileResult = await _FileService.Add(File);

            if (FileResult == null) return BadRequest();

            return Ok(_mapper.Map<VideoFileResultDto>(FileResult));
        }

        [HttpPut("{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> Update(int id, FileEditDto FileDto)
        {
            if (id != FileDto.Id) return BadRequest();

            if (!ModelState.IsValid) return BadRequest();

            await _FileService.Update(_mapper.Map<VideoFile>(FileDto));

            return Ok(FileDto);
        }

        [HttpDelete("{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Remove(int id)
        {
            var File = await _FileService.GetById(id);
            if (File == null) return NotFound();

            await _FileService.Remove(File);

            return Ok();
        }

        [HttpGet]
        [Route("search/{FileName}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<VideoFile>>> Search(string FileName)
        {
            var Files = _mapper.Map<List<VideoFile>>(await _FileService.Search(FileName));

            if (Files == null || Files.Count == 0) return NotFound("None File was founded");

            return Ok(_mapper.Map<IEnumerable<VideoFileResultDto>>(Files));
        }

        [HttpGet]
        [Route("search-File-with-Series/{searchedValue}/{isRandom}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<VideoFile>>> SearchFileWithSeries(string searchedValue, bool isRandom)
        {
            var Files = _mapper.Map<List<VideoFile>>(await _FileService.SearchFileWithSeries(searchedValue, isRandom));

            if (!Files.Any())
                return NotFound("None File was founded");

            return Ok(_mapper.Map<IEnumerable<VideoFileResultDto>>(Files));
        }

        [HttpPut]
        [Route("rate/{videoId}")]
        public async Task<IActionResult> SetRating(int videoId, [FromBody] double value)
        {
            await _FileService.SetRating(videoId, value);
            return Ok();
        }

        private static object _ratingUpdateLock = new object();

        [HttpPut]
        [Route("updatePosition/{videoId}")]
        public async Task<IActionResult> SetPosition(int videoId, [FromBody] double value)
        {
            await _FileService.SetPosition(videoId, value);

            return Ok();
        }

        [HttpGet]
        [Route("getFileById")]
        public async Task<FileResult> GetVideoById(int fileId)
        {
            var logger = NLog.Web.NLogBuilder.ConfigureNLog("NLog.config").GetCurrentClassLogger();

            try
            {
                var file = await _FileService.GetById(fileId);

                var path = file.Path;

                if (file.Path.EndsWith("avi"))
                {
                    path = DbUpdateManager.Encode(path);
                }
                logger.Debug($"getFileById 2 {file.Path}");

                return PhysicalFile($"{path}", "application/octet-stream", enableRangeProcessing: true);
            }
            catch (Exception ex)
            {
                logger.Debug("getFileById 5");
                logger.Error(ex);

                throw;
            }
        }

        [HttpGet]
        [Route("getRandomFileBySeriesId")]
        public async Task<FileResult> GetRandomFileBySeriesId(int seriesId, string guid)
        {
            if (!_randomFileDict.ContainsKey(guid))
            {
                var newFile = await _FileService.GetRandomFileBySeriesId(seriesId);
                _randomFileDict.Add(guid, newFile.Id);
            }

            var fileId = _randomFileDict[guid];

            return await GetVideoById(fileId);
        }

        [HttpGet]
        [Route("getRandomFileIdBySeriesId")]
        public async Task<IActionResult> GetRandomFileIdBySeriesId(int seriesId, string guid)
        {
            var newFile = await _FileService.GetRandomFileBySeriesId(seriesId);

            return Ok(newFile.Id);
        }
    }
}