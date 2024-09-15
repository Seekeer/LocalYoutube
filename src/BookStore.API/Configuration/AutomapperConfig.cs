using AutoMapper;
using Dtos;
using FileStore.Domain.Dtos;
using FileStore.Domain.Models;
using ProtoBuf.WellKnownTypes;
using System;
using System.Collections.Generic;
using System.Linq;

namespace FileStore.API.Configuration
{
    public static class AutomapperHelper
    {
        public static IEnumerable<DTO> GetFiles<T, DTO>(this IMapper mapper, IEnumerable<T> files, string userId)
            where T : DbFile
        {
            var currentTime = TimeSpan.Zero;
            files.ToList().ForEach(x =>
            {
                x.CurrentUserId = userId;
                x.PreviousFilesDurationSeconds = currentTime.TotalSeconds;
                currentTime += x.Duration;
            });

            return mapper.Map<IEnumerable<DTO>>(files);
        }

        public static DTO GetFile<T, DTO>(this IMapper mapper, T file, string userId)
            where T : DbFile
        {
            file.CurrentUserId = userId;

            return mapper.Map<DTO>(file);
        }
    }

    public class AutomapperConfig : Profile
    {
        public AutomapperConfig()
        {
            //CreateMap<byte[], string>().ConvertUsing(new Base64Converter());
            CreateMap<Season, SeasonResultDto>().ReverseMap();
            CreateMap<Series, SeriesResultDto>().ReverseMap();
            CreateMap<Playlist, DtoIdBase>().ReverseMap();
            CreateMap<VideoFile, VideoFileResultDto>().ReverseMap();
            CreateMap<AudioFile, VideoFileResultDto>().ReverseMap();
            CreateMap<FileMark, MarkAddDto>().ReverseMap();
            CreateMap<FileUserInfo, PositionDTO>().ReverseMap();
        }
    }

    internal class Base64Converter : ITypeConverter<byte[], string>
    {
        public string Convert(byte[] source, string destination, ResolutionContext context)
        {
            if (source == null)
                return "";
            try
            {
                return System.Convert.ToBase64String(source);
            }
            catch (System.Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
                return "";
            }

        }
    }
}