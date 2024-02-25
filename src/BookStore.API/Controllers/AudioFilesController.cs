using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using AutoMapper;
using FileStore.API.Configuration;
using FileStore.API.Dtos.File;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using Infrastructure.Scheduler;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

namespace FileStore.API.Controllers
{

    [Authorize]
    [Microsoft.AspNetCore.Cors.EnableCors("CorsPolicy")]
    [Route("api/[controller]")]
    public class AudioFilesController : FilesControllerBase<AudioFile, AudioType, VideoFileResultDto>
    {
        public AudioFilesController(UserManager<ApplicationUser> userManager, IMapper mapper, IAudioFileService FileService) : base(userManager, mapper, FileService)
        {
        }
    }

    [Authorize]
    [Microsoft.AspNetCore.Cors.EnableCors("CorsPolicy")]
    [Route("api/[controller]")]
    public abstract class FilesControllerBase<T,V, DTO> : MainController
        where T : DbFile
    {
        protected readonly UserManager<ApplicationUser> _userManager;
        protected readonly IMapper _mapper;
        protected readonly IFileService<T, V> _fileService;

        public FilesControllerBase(UserManager<ApplicationUser> userManager, IMapper mapper, 
            IFileService<T, V> FileService)
        {
            _userManager = userManager;
            _mapper = mapper;
            _fileService = FileService;
        }

        [HttpGet]
        [AllowAnonymous]
        [Route("getFileById")]
        public async Task<FileResult> GetVideoById(int fileId)
        {
            var logger = NLog.Web.NLogBuilder.ConfigureNLog("NLog.config").GetCurrentClassLogger();

            var stopwatch = Stopwatch.StartNew();

            try
            {

                var file = await _fileService.GetById(fileId);
                var path = file.Path;
                var finfo = new FileInfo(path);

                //return wait TryToDownload(file);

                return PhysicalFile($"{path}", "application/octet-stream", finfo.Name, enableRangeProcessing: true);
            }
            catch (Exception ex)
            {
                logger.Debug("getFileById 5");
                logger.Error(ex);

                throw;
            }
            finally
            {
                stopwatch.Stop();
                logger.Debug($"getFileById {stopwatch.ElapsedMilliseconds}");
            }
        }

        private async Task<FileResult> TryToDownload(T file)
        {
            var path = file.Path;
            var finfo = new FileInfo(path);

            var yadisk = new YandexDisc("AQAAAAABKm0kAAeaqT0Xy-23cEj1usRIZAcnhO0");

            var filepath = @"Z:\Smth\Downloads\Не подтвержден 993352.crdownload";
            await yadisk.Download(filepath, file.Path);

            return PhysicalFile(filepath, "application/octet-stream", finfo.Name, enableRangeProcessing: true);

            //return PhysicalFile(@"Z:\Smth\Downloads\Не подтвержден 993251.crdownload", "application/octet-stream", finfo.Name, enableRangeProcessing: true);
        }

        [HttpDelete("{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Remove(int id)
        {
            var file = await _fileService.GetById(id);

            if (file == null) return NotFound();

            await DoActionBeforeDelete(file);

            await _fileService.Remove(file);

            return Ok();
        }

        protected virtual async Task DoActionBeforeDelete(T file)
        {
        }

        [HttpPatch]
        [Route("filmStarted")]
        public async Task<ActionResult> FilmStarted([FromBody]int fileId)
        {
            await _fileService.SetPosition(fileId, await GetUserId(_userManager), null);

            return Ok();
        }

        [HttpGet]
        [Route("search/{FileName}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<DTO>>> Search(string FileName)
        {
            var Files = _mapper.Map<List<T>>(await _fileService.Search(FileName));

            if (Files == null || Files.Count == 0) return NotFound("None File was founded");

            var resultDTO = _mapper.GetFiles<T, DTO>(Files, await GetUserId(_userManager));
            return Ok(resultDTO);
        }

        [HttpGet]
        [Route("getFilesBySeries")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetFilesBySeries(int id, int count, bool isRandom, int startId)
        {
            var Files = await _fileService.GetFilesBySearies(id, count, isRandom, startId);

            if (!Files.Any())
                return NotFound();

            return Ok(_mapper.GetFiles<T, DTO>(Files, await GetUserId(_userManager)));
        }

        [HttpGet]
        [Route("search-File-with-Season/{seasonId}/{isRandom}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<DTO>>> SearchFileWithSeason(int seasonId, bool isRandom)
        {
            var Files = _mapper.Map<List<T>>(await _fileService.GetFilesBySeason(seasonId, isRandom, 0, 0));

            if (!Files.Any())
                return NotFound("None File was founded");

            return Ok(_mapper.GetFiles<T, DTO>(Files, await GetUserId(_userManager)));
        }

        [HttpPut]
        [Route("setPosition/{id}")]
        public async Task<IActionResult> SetPosition(int id, [FromBody] double value)
        {
            string userId = await GetUserId(_userManager);
            await _fileService.SetPosition(id, userId, value);

            return Ok();
        }

        [HttpGet]
        [Route("getPosition/{fileId}")]
        public async Task<IActionResult> GetPosition(int fileId)
        {
            string userId = await GetUserId(_userManager);
            var position = await _fileService.GetPosition(fileId, userId);

            return Ok(position);
        }

        [HttpGet]
        [Route("getLatest")]
        public async Task<ActionResult<List<DTO>>> GetLatest()
        {
            string userId = await GetUserId(_userManager);
            var files = _mapper.Map<List<T>>(await _fileService.GetLatest(userId));

            return Ok(_mapper.GetFiles<T, DTO>(files, await GetUserId(_userManager)));
        }
    }
}