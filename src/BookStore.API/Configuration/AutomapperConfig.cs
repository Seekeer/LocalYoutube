using AutoMapper;
using FileStore.API.Dtos.File;
using FileStore.API.Dtos.Series;
using FileStore.Domain.Models;
using System.Collections.Generic;
using System.Linq;

namespace FileStore.API.Configuration
{
    public static class AutomapperHelper
    {
        public static IEnumerable<DTO> GetFiles<T, DTO>(this IMapper mapper, IEnumerable<T> files, string userId)
            where T : DbFile
        {
            files.ToList().ForEach(x => x.CurrentUserId = userId);

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
            CreateMap<byte[], string>().ConvertUsing(new Base64Converter());
            CreateMap<Season, SeasonResultDto>().ReverseMap();
            CreateMap<Series, SeriesAddDto>().ReverseMap();
            CreateMap<Series, SeriesEditDto>().ReverseMap();
            CreateMap<Series, SeriesResultDto>().ReverseMap();
            CreateMap<VideoFile, FileAddDto>().ReverseMap();
            CreateMap<VideoFile, FileEditDto>().ReverseMap();
            CreateMap<VideoFile, VideoFileResultDto>().ReverseMap();
            CreateMap<AudioFile, VideoFileResultDto>().ReverseMap();
        }
    }

    internal class Base64Converter : ITypeConverter<byte[], string>
    {
        public string Convert(byte[] source, string destination, ResolutionContext context)
        {
            if (source == null)
                return "";

            return System.Convert.ToBase64String(source);
        }
    }
}