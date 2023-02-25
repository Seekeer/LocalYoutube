using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using FileStore.API.Configuration;
using FileStore.API.Dtos.File;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Domain.Services;
using Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FileStore.API.Controllers
{

    [Authorize]
    [Microsoft.AspNetCore.Cors.EnableCors("CorsPolicy")]
    [Route("api/[controller]")]
    public class FilesController : MainController
    {
        private readonly IFileService _FileService;
        private readonly ISeriesService _seriesService;
        private readonly IMapper _mapper;
        private readonly static Dictionary<string, int> _randomFileDict = new Dictionary<string, int>();

        public FilesController(IMapper mapper, IFileService FileService, ISeriesService seriesService)
        {
            _mapper = mapper;
            _FileService = FileService;
            _seriesService = seriesService;
        }

        [HttpGet]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAll()
        {
            var Files = await _FileService.GetAll();

            return Ok(_mapper.GetFiles(Files, GetUserId()));
        }

        [HttpGet("{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetById(int id)
        {
            var File = await _FileService.GetById(id);

            if (File == null) return NotFound();

            return Ok(_mapper.GetFile(File, GetUserId()));
        }

        [HttpGet]
        [Route("getFilesBySeries")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetFilesBySeries(int id, int count, bool isRandom, int startId)
        {
            var Files = await _FileService.GetFilesBySearies(id, isRandom, startId);

            if (!Files.Any())
                return NotFound();

            return Ok(_mapper.GetFiles(Files, GetUserId()));
        }

        [HttpGet]
        [Route("getFilesBySeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetFilesBySeason(int id, int count, bool isRandom, int startId)
        {
            var Files = await _FileService.GetFilesBySeason(id, isRandom, count, startId);

            if (!Files.Any())
                return NotFound();

            return Ok(_mapper.GetFiles(Files, GetUserId()));
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

            var resultDTO = _mapper.GetFiles(Files, GetUserId());
            return Ok(resultDTO);
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

            return Ok(_mapper.GetFiles(Files, GetUserId()));
        }

        private string GetUserId()
        {
            var user = HttpContext.User;
            var id = user.Claims.FirstOrDefault(x => x.Type == ClaimTypes.Hash)?.Value;
            return id;
        }

        [HttpGet]
        [Route("search-File-with-Season/{seasonId}/{isRandom}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<VideoFile>>> SearchFileWithSeason(int seasonId, bool isRandom)
        {
            var Files = _mapper.Map<List<VideoFile>>(await _FileService.GetFilesBySeason(seasonId, isRandom, 0, 0));

            if (!Files.Any())
                return NotFound("None File was founded");

            return Ok(_mapper.GetFiles(Files, GetUserId()));
        }

        [HttpGet]
        [Route("getAnimation")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<VideoFile>>> GetAnimation(bool isSoviet)
        {
            var files = await _FileService.SearchFileByType(VideoType.Animation);

            if (isSoviet)
                files = files.Where(x => x.Origin == Origin.Soviet).Take(30);
            else 
                files = files.Where(x => x.Origin != Origin.Soviet);

            var result= _mapper.Map<List<VideoFile>>(files).OrderByDescending(x => x.Name);

            if (!result.Any())
                return NotFound("None File was founded");

            return Ok(_mapper.GetFiles(result, GetUserId())); 
        }

        [HttpGet]
        [Route("getFileByType/{type}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<VideoFile>>> GetFileByType(VideoType type)
        {
            var result = await _FileService.SearchFileByType(type);
            var Files = _mapper.Map<List<VideoFile>>(result);

            if (!Files.Any())
                return NotFound("None File was founded");

            var filesDTO = _mapper.GetFiles(Files, GetUserId()).OrderByDescending(x => x.Year);
            return Ok(filesDTO);
        }

        [HttpGet]
        [Route("getFileByTypeUniqueSeason/{type}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<VideoFile>>> GetFileByTypeUniqueSeason(VideoType type)
        {
            var result = await _FileService.SearchFileByType(type);
            var files = _mapper.Map<List<VideoFile>>(result);

            if (!files.Any())
                return NotFound("None File was founded");

            var seasons = (await _seriesService.GetAllByType(VideoType.Art)).SelectMany(x => x.Seasons);
            var unique = files.OrderBy(x => x.Id).GroupBy(x => x.SeasonId).Select(x => {
                var file = x.First(); 
                if (x.Count() > 1)
                    file.Name = seasons.FirstOrDefault(x => x.Id == file.SeasonId).Name;
                return file;
                }
            ).ToList();

            var filesDTO = _mapper.GetFiles(unique, GetUserId()).OrderByDescending(x => x.Year);
            foreach (var file in filesDTO)
                file.IsFinished = false;

            return Ok(filesDTO);
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
            string userId = GetUserId();
            await _FileService.SetPosition(videoId, value, userId);

            return Ok();
        }

        [HttpGet]
        [AllowAnonymous]
        [Route("getFileById")]
        public async Task<FileResult> GetVideoById(int fileId)
        {
            var logger = NLog.Web.NLogBuilder.ConfigureNLog("NLog.config").GetCurrentClassLogger();

            try
            {
                var file = await _FileService.GetById(fileId);

                var path = file.Path;

                //if (file.Path.EndsWith("avi"))
                //{
                //    path = DbUpdateManager.EncodeToMp4(path);
                //}
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