using AutoMapper;
using FileStore.API.Dtos.File;
using FileStore.API.Dtos.Series;
using FileStore.Domain.Models;

namespace FileStore.API.Configuration
{
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
            CreateMap<VideoFile, VideoFileResultDto>().ReverseMap();
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