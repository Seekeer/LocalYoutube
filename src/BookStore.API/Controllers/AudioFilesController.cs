using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net.Http;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using AutoMapper;
using Dtos;
using FileStore.API.Configuration;
using FileStore.Domain.Dtos;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using Infrastructure;
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
        private readonly FileManager _fileManager;

        public AudioFilesController(UserManager<ApplicationUser> userManager, IMapper mapper, IAudioFileService FileService, FileManager fileManager) : base(userManager, mapper, FileService)
        {
            _fileManager = fileManager;
        }

        [HttpGet]
        [AllowAnonymous]
        [Route("downloadSeason/{seasonId}")]
        public async Task<FileResult> ZipSeason(int seasonId)
        {
            var files = await _fileService.GetFilesBySeason(seasonId, false, 0, 0);

            if (!files.Any())
                throw new ArgumentException("None File was founded");

            var tempFile = _fileManager.ZipFiles(files);
            var stream = new FileStream(tempFile, FileMode.Open);

            return PhysicalFile($"{tempFile}", "application/zip", files.First().Name, enableRangeProcessing: true);
        }
    }

    [Authorize]
    [Microsoft.AspNetCore.Cors.EnableCors("CorsPolicy")]
    [Route("api/[controller]")]
    public abstract class FilesControllerBase<F,V, DTO> : MainController
        where F : DbFile
        where DTO : IDtoId
    {
        protected readonly UserManager<ApplicationUser> _userManager;
        protected readonly IMapper _mapper;
        protected readonly IFileService<F, V> _fileService;

        public FilesControllerBase(UserManager<ApplicationUser> userManager, IMapper mapper, 
            IFileService<F, V> FileService)
        {
            _userManager = userManager;
            _mapper = mapper;
            _fileService = FileService;
        }

        [AllowAnonymous]
        [HttpGet]
        [Route("getImage")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetImage(int fileId)
        {
            var file = await _fileService.GetById(fileId);

            if (file?.Cover == null)
                return NotFound();

            // Replace the octet-stream with whatever type you desire, we decided on the basic, generic form because... well, it all is, isn't it?
            return File(file.VideoFileExtendedInfo.Cover, "application/octet-stream", "cover.jpeg");
        }

        [HttpPost]
        [Route("updateFile")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> Update([FromBody] DTO dto)
        {
            var file = await _fileService.GetById(dto.Id);

            file.Name = dto.Name;

            await _fileService.Update(file);

            return Ok();
        }

        [HttpPost]
        [Route("move-file-to-season/{fileId}/{seasonId}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveToSeason(int fileId, int seasonId)
        {
            return Ok(await _fileService.MoveToSeason(fileId, seasonId));
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
                if (file.IsSupportedWebPlayer)
                    return PhysicalFile($"{path}", "application/octet-stream", finfo.Name, enableRangeProcessing: true);
                else
                    return await ConvertOnTheFly(file);
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


        private async Task<FileResult> ConvertOnTheFly(F file)
        {
            throw new NotImplementedException();
        }

        [HttpGet]
        [AllowAnonymous]
        [Route("convertFileById")]
        public async Task<ActionResult> ConvertVideoById(int fileId)
        {
            throw new NotImplementedException();
            //var ffmpegCommandLineArguments = _encodingHelper.GetProgressiveVideoFullCommandLine(state, encodingOptions, EncoderPreset.superfast);
            //using (await transcodeManager.LockAsync(outputPath, cancellationTokenSource.Token).ConfigureAwait(false))
            //{
            //    TranscodingJob? job;
            //    if (!File.Exists(outputPath))
            //    {
            //        job = await transcodeManager.StartFfMpeg(
            //            state,
            //            outputPath,
            //            ffmpegCommandLineArguments,
            //            HttpContext.User.GetUserId(),
            //            transcodingJobType,
            //            cancellationTokenSource).ConfigureAwait(false);
            //    }
            //    //else
            //    //{
            //    //    job = transcodeManager.OnTranscodeBeginRequest(outputPath, TranscodingJobType.Progressive);
            //    //    state.Dispose();
            //    //}

            //    var stream = new ProgressiveFileStream(outputPath, job, transcodeManager);
            //    return new FileStreamResult(stream, "application/octet-stream");
            //}
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

        protected virtual async Task DoActionBeforeDelete(F file)
        {
        }

        [HttpPatch]
        [Route("filmStarted")]
        public async Task<ActionResult> FilmStarted([FromBody]int fileId)
        {
            await _fileService.SetPosition(fileId, await GetUserId(_userManager), null, null);

            return Ok();
        }

        [HttpGet]
        [Route("search/{FileName}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<DTO>>> Search(string FileName)
        {
            var Files = _mapper.Map<List<F>>(await _fileService.Search(FileName));

            if (Files == null || Files.Count == 0) return NotFound("None File was founded");

            var resultDTO = _mapper.GetFiles<F, DTO>(Files, await GetUserId(_userManager));
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

            return Ok(_mapper.GetFiles<F, DTO>(Files, await GetUserId(_userManager)));
        }

        [HttpGet]
        [Route("search-File-with-Season/{seasonId}/{isRandom}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<DTO>>> SearchFileWithSeason(int seasonId, bool isRandom)
        {
            var Files = _mapper.Map<List<F>>(await _fileService.GetFilesBySeason(seasonId, isRandom, 0, 0));

            if (!Files.Any())
                return NotFound("None File was founded");

            return Ok(_mapper.GetFiles<F, DTO>(Files, await GetUserId(_userManager)));
        }

        [HttpPut]
        [Route("setPosition/{id}")]
        public async Task<IActionResult> SetPosition(int id, [FromBody] double value)
        {
            string userId = await GetUserId(_userManager);
            await _fileService.SetPosition(id, userId, value, null);

            return Ok();
        }

        [HttpGet]
        [Route("getPosition/{fileId}")]
        public async Task<IActionResult> GetPosition(int fileId)
        {
            string userId = await GetUserId(_userManager);
            var info = await _fileService.GetPosition(fileId, userId);

            return Ok(info.Position);
        }

        [HttpPut]
        [Route("setPositionMaui/{id}")]
        public async Task<IActionResult> SetPositionMaui(int id, [FromBody] PositionDTO position)
        {
            string userId = await GetUserId(_userManager);
            var result = await _fileService.SetPosition(id, userId, position.Position, position.UpdatedDate);

            return Ok(result);
        }

        [HttpGet]
        [Route("getPositionMaui/{fileId}")]
        public async Task<IActionResult> GetPositionMaui(int fileId)
        {
            string userId = await GetUserId(_userManager);
            var info = await _fileService.GetPosition(fileId, userId);

            var dto = _mapper.Map<PositionDTO>(info);

            return Ok(dto);
        }

        [HttpGet]
        [Route("getLatest")]
        public async Task<ActionResult<List<DTO>>> GetLatest()
        {
            string userId = await GetUserId(_userManager);
            var files = _mapper.Map<List<F>>(await _fileService.GetLatest(userId));

            return Ok(_mapper.GetFiles<F, DTO>(files, await GetUserId(_userManager)));
        }

        [HttpGet]
        [Route("getNew")]
        public async Task<ActionResult<List<DTO>>> GetNew(int count = 50)
        {
            var files = _mapper.Map<List<F>>(await _fileService.GetNew(count));

            return Ok(_mapper.GetFiles<F, DTO>(files, await GetUserId(_userManager)));
        }
    }
}