using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using AutoMapper;
using FileStore.API.Configuration;
using FileStore.API.Dtos.File;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
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

            try
            {
                var file = await _fileService.GetById(fileId);

                var path = file.Path;

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
        [Route("search-File-with-Series/{searchedValue}/{isRandom}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<DTO>>> SearchFileWithSeries(string searchedValue, bool isRandom)
        {
            var Files = _mapper.Map<List<T>>(await _fileService.SearchFileWithSeries(searchedValue, isRandom));

            if (!Files.Any())
                return NotFound("None File was founded");

            return Ok(_mapper.GetFiles<T,DTO>(Files, await GetUserId(_userManager)));
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
        [Route("updatePosition/{id}")]
        public async Task<IActionResult> SetPosition(int id, [FromBody] double value)
        {
            string userId = await GetUserId(_userManager);
            await _fileService.SetPosition(id, value, userId);

            return Ok();
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