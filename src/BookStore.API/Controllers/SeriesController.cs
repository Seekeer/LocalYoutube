﻿using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using AutoMapper;
using Dtos;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Domain.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace FileStore.API.Controllers
{
    [Microsoft.AspNetCore.Cors.EnableCors("CorsPolicy")]
    [Route("api/[controller]")]
    [Authorize]
    public class SeriesController : MainController
    {
        private readonly ISeriesService _SeriesService;
        private readonly ISeriesRepository _SeriesRepository;
        private readonly IMapper _mapper;

        public SeriesController(IMapper mapper, ISeriesService SeriesService, ISeriesRepository SeriesRepository)
        {
            _mapper = mapper;
            _SeriesService = SeriesService;
            _SeriesRepository = SeriesRepository;
        }

        [HttpGet]
        [Route("getAllAudio")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAllAudio(AudioType? type = null, AudioType? exceptType = null)
        {
            var series = new List<Series>();

            if (type == null && exceptType != null)
            {
                foreach (AudioType enumType in Enum.GetValues(typeof(AudioType)))
                {
                    if (enumType != exceptType)
                        series.AddRange(await _SeriesService.GetAllByType(enumType));
                }
            }
            else
                series.AddRange(await _SeriesService.GetAllByType(type));

            return Ok(_mapper.Map<IEnumerable<SeriesResultDto>>(series));
        }

        [HttpGet]
        [Route("moveSeasonToFavorite")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveSeasonToFavorite(int seasonId, bool favorite)
        {
            await _SeriesService.MoveSeasonToFavorite(seasonId, favorite);

            return Ok();
        }

        [HttpGet]
        [Route("moveSeasonToSeries")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> MoveToSeason(int fileId, int seriesId)
        {
            await _SeriesRepository.MoveSeasonToSeriesAsync(fileId, seriesId);
            return Ok();
        }

        [HttpGet]
        [Route("getAllByType")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAll(VideoType? type = null)
        {
            return await GetAll(type, null);
        }

        [HttpGet]
        [Route("getAllByOrigin")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAll(Origin? origin = null)
        {
            return await GetAll(null, origin);
        }

        [HttpGet]
        [Route("getFreshSeasons")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetFreshSeasons(int number = 20)
        {
            var seasons = await _SeriesRepository.GetFreshSeasonsAsync(number);
            var freashSeries = new List<Series>{ new Series {
                Seasons = seasons,
            } };
            return Ok(_mapper.Map<IEnumerable<SeriesResultDto>>(freashSeries));
        }

        private async Task<IActionResult> GetAll(VideoType? type = null, Origin? origin = null)
        {
            var Series = await _SeriesService.GetAllByType(type, origin);

            return Ok(_mapper.Map<IEnumerable<SeriesResultDto>>(Series));
        }

        [HttpGet]
        [Route("specialAndEot")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> SpecialAndEot()
        {
            var series = new List<Series>();
            series.AddRange(await _SeriesService.GetAllByType(VideoType.Special, null));
            series.AddRange(await _SeriesService.GetAllByType(VideoType.EoT, null));

            return Ok(_mapper.Map<IEnumerable<SeriesResultDto>>(series));
        }

        [HttpGet]
        [Route("courses")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> Courses()
        {
            var series = new List<Series>();
            series.AddRange(await _SeriesService.GetAllByType(VideoType.Courses, null));

            return Ok(_mapper.Map<IEnumerable<SeriesResultDto>>(series));
        }

        [HttpGet]
        [Route("adultEpisode")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> AdultEpisode()
        {
            var series = new List<Series>();
            series.AddRange(await _SeriesService.GetAllByType(VideoType.AdultEpisode, null));

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

        [HttpDelete("season/{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> RemoveSeason(int id)
        {
            var result = await  _SeriesService.RemoveSeasonById(id);

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