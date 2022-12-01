using System.Collections.Generic;
using System.Threading.Tasks;
using AutoMapper;
using FileStore.API.Dtos.Series;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace FileStore.API.Controllers
{
    [Route("api/[controller]")]
    public class SeriesController : MainController
    {
        private readonly ISeriesService _SeriesService;
        private readonly IMapper _mapper;

        public SeriesController(IMapper mapper,
                                    ISeriesService SeriesService)
        {
            _mapper = mapper;
            _SeriesService = SeriesService;
        }

        [HttpGet]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAll(VideoType? type = null)
        {
            var Series = await _SeriesService.GetAllByType(type);

            return Ok(_mapper.Map<IEnumerable<SeriesResultDto>>(Series));
        }

        [HttpGet]
        [Route("other")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> SeriesOther()
        {
            var series = new List<Series>();
            series.AddRange(await _SeriesService.GetAllByType(VideoType.AdultEpisode));
            series.AddRange(await _SeriesService.GetAllByType(VideoType.Courses));
            series.AddRange(await _SeriesService.GetAllByType(VideoType.Youtube));

            return Ok(_mapper.Map<IEnumerable<SeriesResultDto>>(series));
        }

        [HttpGet("{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetById(int id)
        {
            var Series = await _SeriesService.GetById(id);

            if (Series == null) return NotFound();

            return Ok(_mapper.Map<SeriesResultDto>(Series));
        }

        [HttpPost]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> Add(SeriesAddDto SeriesDto)
        {
            if (!ModelState.IsValid) return BadRequest();

            var series = _mapper.Map<Series>(SeriesDto);
            var SeriesResult = await _SeriesService.Add(series);

            if (SeriesResult == null) return BadRequest();

            return Ok(_mapper.Map<SeriesResultDto>(SeriesResult));
        }

        [HttpPut("{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> Update(int id, SeriesEditDto SeriesDto)
        {
            if (id != SeriesDto.Id) return BadRequest();

            if (!ModelState.IsValid) return BadRequest();

            await _SeriesService.Update(_mapper.Map<Series>(SeriesDto));

            return Ok(SeriesDto);
        }

        [HttpDelete("{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Remove(int id)
        {
            var Series = await _SeriesService.GetById(id);
            if (Series == null) return NotFound();

            var result = await _SeriesService.Remove(Series);

            if (!result) return BadRequest();

            return Ok();
        }

        [HttpGet]
        [Route("search/{Series}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<List<Season>>> Search(string series)
        {
            var result = _mapper.Map<List<Season>>(await _SeriesService.Search(series, 10));

            if (result == null || result.Count == 0)
                return NotFound("None Series was founded");

            return Ok(result);
        }
    }
}