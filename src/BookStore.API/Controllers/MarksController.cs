using AutoMapper;
using FileStore.API.Controllers;
using FileStore.API.Dtos.Series;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Domain.Services;
using FileStore.Infrastructure.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace API.Controllers
{

    [Microsoft.AspNetCore.Cors.EnableCors("CorsPolicy")]
    [Route("api/[controller]")]
    [Authorize]
    public class MarksController : MainController
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IMapper _mapper;
        private readonly IMarksRepository _marksRepository;

        public MarksController(UserManager<ApplicationUser> userManager, IMapper mapper, IMarksRepository marksRepository)
        {
            _userManager = userManager;
            _mapper = mapper;
            _marksRepository = marksRepository;
        }

        [HttpGet]
        [Route("getAllMarks")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAllAudio(int fileId)
        {
            var userId = await GetUserId(_userManager);
            var objects = (await _marksRepository.GetAll()).Where(x => x.DbFileId == fileId && x.UserId == userId);

            return Ok(objects);
        }

        [HttpPost]
        [Route("add")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> Add(MarkAddDto dto)
        {
            if (!ModelState.IsValid) return BadRequest();
            var userId = await GetUserId(_userManager);

            var mark = _mapper.Map<FileMark>(dto);
            mark.UserId = userId;
            var addedMark = await _marksRepository.Add(mark);

            return Ok(addedMark.Id);
        }

        [HttpDelete("{id:int}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Remove(int id)
        {
            await _marksRepository.Remove(id);

            return Ok();
        }
    }
}
