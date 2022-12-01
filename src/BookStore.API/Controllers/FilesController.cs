using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using FileStore.API.Dtos.File;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using Infrastructure;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FileStore.API.Controllers
{

    [EnableCors()]
    [Route("api/[controller]")]
    public class FilesController : MainController
    {
        private readonly IFileService _FileService;
        private readonly IMapper _mapper;
        private readonly static Dictionary<string, int> _randomFileDict = new Dictionary<string, int>();

        public FilesController(IMapper mapper, IFileService FileService)
        {
            _mapper = mapper;
            _FileService = FileService;
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

            var resultDTO = _mapper.Map<IEnumerable<VideoFileResultDto>>(Files);
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

            return Ok(_mapper.Map<IEnumerable<VideoFileResultDto>>(Files));
        }

        [HttpGet]
        [Route("search-File-with-Season/{seasonId}/{isRandom}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<VideoFile>>> SearchFileWithSeason(int seasonId, bool isRandom)
        {
            var Files = _mapper.Map<List<VideoFile>>(await _FileService.GetFilesBySeason(seasonId, isRandom, 0));

            if (!Files.Any())
                return NotFound("None File was founded");

            return Ok(_mapper.Map<IEnumerable<VideoFileResultDto>>(Files));
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

            return Ok(_mapper.Map<IEnumerable<VideoFileResultDto>>(result));
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

            var filesDTO = _mapper.Map<IEnumerable<VideoFileResultDto>>(Files).OrderByDescending(x=> x.Year);
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