using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using API.Controllers;
using AutoMapper;
using FileStore.API.Configuration;
using FileStore.API.Dtos.File;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Domain.Services;
using Google.Apis.CustomSearchAPI.v1.Data;
using Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TL;

namespace FileStore.API.Controllers
{
    [Authorize]
    [Microsoft.AspNetCore.Cors.EnableCors("CorsPolicy")]
    [Route("api/[controller]")]
    public class FilesController : FilesControllerBase<VideoFile, VideoType, VideoFileResultDto>
    {
        private readonly IRuTrackerUpdater _ruTrackerUpdater;
        private readonly ISeriesService _seriesService;
        private readonly static Dictionary<string, int> _randomFileDict = new Dictionary<string, int>();

        public FilesController(UserManager<ApplicationUser> userManager, IMapper mapper, IVideoFileService FileService, 
            ISeriesService seriesService, IRuTrackerUpdater ruTrackerUpdater) : base(userManager, mapper, FileService)
        {
            _ruTrackerUpdater = ruTrackerUpdater;
            _seriesService = seriesService;
        }

        //[AllowAnonymous]
        //[HttpGet("pki-validation/500FFD61F19597364C13E9F8B80E0F0B.txt")]
        //[ProducesResponseType(StatusCodes.Status200OK)]
        //public async Task<IActionResult> GetById()
        //{
        //    return File(System.IO.File.ReadAllBytes(@"Z:\Smth\Downloads\500FFD61F19597364C13E9F8B80E0F0B.txt"), @"text/plain");
        //}


        [HttpGet]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAll()
        {
            var Files = await _fileService.GetAll();

            return Ok(_mapper.GetFiles<VideoFile, VideoFileResultDto>(Files,await GetUserId(_userManager)));
        }

        [HttpGet("{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetById(int id)
        {
            var File = await _fileService.GetById(id);

            if (File == null) return NotFound();

            return Ok(_mapper.GetFile<VideoFile, VideoFileResultDto>(File,await GetUserId(_userManager)));
        }

        [HttpGet]
        [Route("getFilesBySeries")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetFilesBySeries(int id, int count, bool isRandom, int startId)
        {
            var Files = await _fileService.GetFilesBySearies(id, isRandom, startId);

            if (!Files.Any())
                return NotFound();

            return Ok(_mapper.GetFiles<VideoFile, VideoFileResultDto>(Files,await GetUserId(_userManager)));
        }

        [HttpGet]
        [Route("getFilesBySeason")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetFilesBySeason(int id, int count, bool isRandom, int startId)
        {
            var Files = await _fileService.GetFilesBySeason(id, isRandom, count, startId);

            if (!Files.Any())
                return NotFound();

            return Ok(_mapper.GetFiles<VideoFile, VideoFileResultDto>(Files,await GetUserId(_userManager)));
        }

        [HttpDelete("{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Remove(int id)
        {
            var file = await _fileService.GetById(id);

            if (file == null) return NotFound();

            await _ruTrackerUpdater.DeleteTorrent(file.VideoFileExtendedInfo.RutrackerId.ToString());

            await _fileService.Remove(file);

            return Ok();
        }


        [HttpGet]
        [Route("getAnimation")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<VideoFile>>> GetAnimation(bool isSoviet)
        {
            var files = await _fileService.SearchFileByType(VideoType.Animation);
            if (isSoviet)
                files = files.Where(x => x.Origin == Origin.Soviet).Take(30);
            else
                files = files.Where(x => x.Origin != Origin.Soviet);

            var result = _mapper.Map<List<VideoFile>>(files).OrderByDescending(x => x.Name);

            if (!result.Any())
                return NotFound("None file was founded");

            return Ok(_mapper.GetFiles<VideoFile, VideoFileResultDto>(result,await GetUserId(_userManager)));
        }

        [HttpGet]
        [Route("getFileByType/{type}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<VideoFile>>> GetFileByType(VideoType type)
        {
            var result = await _fileService.SearchFileByType(type);
            var Files = _mapper.Map<List<VideoFile>>(result);

            if (!Files.Any())
                return NotFound("None file was founded");

            var filesDTO = _mapper.GetFiles<VideoFile, VideoFileResultDto>(Files,await GetUserId(_userManager)).OrderByDescending(x => x.Year);
            return Ok(filesDTO);
        }

        [HttpGet]
        [Route("moveFileToSerie")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveFile(int fileId, int serieId)
        {
            await _fileService.MoveToSerie(fileId, serieId);
            return Ok();
        }

        [AllowAnonymous]
        [HttpGet]
        [Route("getImage")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetImage(int fileId)
        {
            var file = await _fileService.GetById(fileId);

            if (file.Cover == null)
                return NotFound();

            // Replace the octet-stream with whatever type you desire, we decided on the basic, generic form because... well, it all is, isn't it?
            return File(file.VideoFileExtendedInfo.Cover, "application/octet-stream", "cover.jpeg");
        }

        [HttpGet]
        [Route("getFileByTypeUniqueSeason/{type}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<VideoFile>>> GetFileByTypeUniqueSeason(VideoType type)
        {
            var result = await _fileService.SearchFileByType(type);
            var files = _mapper.Map<List<VideoFile>>(result);

            if (!files.Any())
                return NotFound("None file was founded");

            var seasons = (await _seriesService.GetAllByType(VideoType.Art)).SelectMany(x => x.Seasons);
            var unique = files.OrderBy(x => x.Id).GroupBy(x => x.SeasonId).Select(x =>
            {
                var file = x.First();
                if (x.Count() > 1)
                    file.Name = seasons.FirstOrDefault(x => x.Id == file.SeasonId).Name;
                return file;
            }
            ).ToList();

            var filesDTO = _mapper.GetFiles<VideoFile, VideoFileResultDto>(unique,await GetUserId(_userManager)).OrderByDescending(x => x.Year);
            foreach (var file in filesDTO)
                file.IsFinished = false;

            return Ok(filesDTO);
        }

        [HttpPut]
        [Route("rate/{videoId}")]
        public async Task<IActionResult> SetRating(int videoId, [FromBody] double value)
        {
            await _fileService.SetRating(videoId, value);
            return Ok();
        }

        [HttpGet]
        [Route("getRandomFileBySeriesId")]
        public async Task<FileResult> GetRandomFileBySeriesId(int seriesId, string guid)
        {
            if (!_randomFileDict.ContainsKey(guid))
            {
                var newFile = await _fileService.GetRandomFileBySeriesId(seriesId);
                _randomFileDict.Add(guid, newFile.Id);
            }

            var fileId = _randomFileDict[guid];

            return await GetVideoById(fileId);
        }

        [HttpGet]
        [Route("getRandomFileIdBySeriesId")]
        public async Task<IActionResult> GetRandomFileIdBySeriesId(int seriesId, string guid)
        {
            var newFile = await _fileService.GetRandomFileBySeriesId(seriesId);

            return Ok(newFile.Id);
        }

    }
}