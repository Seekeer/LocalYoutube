using FileStore.Domain.Models;
using System.Collections.Generic;

namespace FileStore.API.Dtos.Series
{
    public class SeriesResultDto
    {
        public int Id { get; set; }

        public string Name { get; set; }
        public bool IsOrderMatter { get; set; }
        public VideoType? Type { get; set; }
        public IEnumerable<SeasonResultDto> Seasons { get; set; }
    }

    public class SeasonResultDto
    {
        public int Id { get; set; }

        public string Name { get; set; }
        public bool IsOrderMatter { get; set; }
    }
}