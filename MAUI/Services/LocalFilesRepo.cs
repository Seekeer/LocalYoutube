using AutoMapper;
using Dtos;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MAUI.Services
{

    public class AutomapperConfig : Profile
    {
        public AutomapperConfig()
        {
            CreateMap<VideoFile, VideoFileResultDto>().ReverseMap();
            CreateMap<AudioFile, VideoFileResultDto>().ReverseMap();
        }
    }

    public class LocalFilesRepo
    {
        private readonly IMapper _mapper;
        private readonly IVideoFileRepository _videoFileRepository;

        public LocalFilesRepo( IVideoFileRepository videoFileRepository)
        //public LocalFilesRepo(IMapper mapper, IVideoFileRepository videoFileRepository)
        {
            //_mapper = mapper;
            _videoFileRepository = videoFileRepository;
        }


        public async Task<IEnumerable<VideoFileResultDto>> GetFiles()
        {
            var localFiles = await _videoFileRepository.GetAll();

            var resultDTO = localFiles.Where(x => !string.IsNullOrEmpty(x.Path)).Select(x => new VideoFileResultDto { Description = x.Description, Id = x.Id, Name = x.Name});
            //var resultDTO = _mapper.Map<IEnumerable<VideoFileResultDto>>(localFiles.Where(x => !string.IsNullOrEmpty(x.Path)));
            return resultDTO;
        }
    }
}
