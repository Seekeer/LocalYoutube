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
using FileStore.API.Configuration;
using System.Linq;

namespace FileStore.API.Controllers
{
    [Microsoft.AspNetCore.Cors.EnableCors("CorsPolicy")]
    [Route("api/[controller]")]
    [Authorize]
    public class PlaylistsController : MainController
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IMapper _mapper;
        private readonly IPlaylistRepository _playlistRepository;

        public PlaylistsController(UserManager<ApplicationUser> userManager, IMapper mapper, IPlaylistRepository playlistRepository)
        {
            _userManager = userManager;
            _mapper = mapper;
            _playlistRepository = playlistRepository;
        }

        [HttpGet]
        [Route("getAll")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAll()
        {
            var playlists = await _playlistRepository.GetAll();
            return Ok(_mapper.Map<IEnumerable<DtoIdBase>>(playlists));
        }

        [HttpGet]
        [Route("getFiles")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetFilesFromPlaylist(int id, int count = 20)
        {
            var playlist = await _playlistRepository.GetById(id);

            var itemsFiles = playlist.Items.Take(count).OrderBy(x => x.Index).Select(x => x.File);
            return Ok(_mapper.GetFiles<DbFile, VideoFileResultDto>(itemsFiles, await GetUserId(_userManager)));
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