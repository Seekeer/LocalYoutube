using AutoMapper;
using Dtos;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using MAUI.ViewModels;
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
        {
            _videoFileRepository = videoFileRepository;
        }

        public async Task<IEnumerable<VideoFileResultDto>> GetFiles()
        {
            var localFiles = await _videoFileRepository.GetAll();

            //for (int i = 0; i < 10; i++)
            //    localFiles.Add(localFiles[0]);

            var resultDTO = localFiles.Where(x => !string.IsNullOrEmpty(x.Path))
                .OrderByDescending(x => x.UpdatedDate)
                .Select(x => new VideoFileResultDtoDownloaded
                {
                    Description = x.Description,
                    Id = x.Id,
                    Name = x.Name,
                    IsDownloaded = true,
                    Path = x.Path,
                    Duration = x.Duration
                });
            //var resultDTO = _mapper.Map<IEnumerable<VideoFileResultDto>>(localFiles.Where(x => !string.IsNullOrEmpty(x.Path)));
            return resultDTO;
        }
    }
}
