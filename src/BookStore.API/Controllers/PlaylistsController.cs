using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using AutoMapper;
using Dtos;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Domain.Services;
using FileStore.Infrastructure.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;

namespace FileStore.API.Controllers
{
    [Microsoft.AspNetCore.Cors.EnableCors("CorsPolicy")]
    [Route("api/[controller]")]
    [Authorize]
    public class PlaylistsController : MainController
    {
        private readonly IMapper _mapper;
        private readonly IPlaylistRepository _playlistRepository;

        public PlaylistsController(IMapper mapper, IPlaylistRepository playlistRepository)
        {
            _mapper = mapper;
            _playlistRepository = playlistRepository;
        }

        [HttpGet]
        [Route("getAll")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAll()
        {
            return Ok(_playlistRepository.GetAll());
        }

        [HttpPost]
        [Route("add")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> Add(Playlist dto)
        {
            if (!ModelState.IsValid) return BadRequest();

            await _playlistRepository.AddAsync(dto);

            return Ok(dto.Id);
        }

        [HttpPost]
        [Route("addToPlaylist")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> AddToPlaylist(AddToPlaylistDTO dto)
        {
            if (!ModelState.IsValid) return BadRequest();

            await _playlistRepository.AddToListAsync(dto.PlaylistId, dto.FileId);

            return Ok();
        }

    }
}