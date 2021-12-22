using System.Collections.Generic;
using System.Linq;
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

        public FilesController(IMapper mapper, IFileService FileService, VideoCatalogDbContext dbContext)
        {
            _mapper = mapper;
            _FileService = FileService;
            _db = dbContext;
        }

        [HttpGet]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAll()
        {
            var dbUpdater = new DbUpdateManager(_db);
            dbUpdater.FillSeries(@"D:\Мульты\YandexDisk\Анюта\Мультсериалы");
            //dbUpdater.FillSeries(@"Z:\Smth\Bittorrent\Анюта\Сериалы");

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
        [Route("get-Files-by-Series/{SeriesId:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetFilesBySeries(int SeriesId)
        {
            var Files = await _FileService.GetFilesBySearies(SeriesId);

            if (!Files.Any()) return NotFound();

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

            return Ok(Files);
        }

        [HttpGet]
        [Route("search-File-with-Series/{searchedValue}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<VideoFile>>> SearchFileWithSeries(string searchedValue)
        {
            var Files = _mapper.Map<List<VideoFile>>(await _FileService.SearchFileWithSeries(searchedValue));

            if (!Files.Any()) return NotFound("None File was founded");

            return Ok(_mapper.Map<IEnumerable<VideoFileResultDto>>(Files));
        }

        [HttpGet]
        [Route("getFileById")]
        public async Task<FileResult> GetVideoById(int fileId)
        {
            var file = await _FileService.GetById(fileId);
            return PhysicalFile($"{file.Path}", "application/octet-stream", enableRangeProcessing: true);
        }

        [HttpGet]
        [Route("getRandomFileBySeriesId")]
        public async Task<FileResult> GetRandomFileBySeriesId(int seriesId)
        {
            var file = await _FileService.GetRandomFileBySeriesId(seriesId);
            return PhysicalFile($"{file.Path}", "application/octet-stream", enableRangeProcessing: true);
        }
    }
}