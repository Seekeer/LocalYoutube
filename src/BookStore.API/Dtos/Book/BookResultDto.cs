using System;

namespace FileStore.API.Dtos.File
{
    public class VideoFileResultDto
    {
        public int Id { get; set; }

        public int SeriesId { get; set; }

        public string SeriesName { get; set; }

        public string Name { get; set; }
        public string Cover { get; set; }

        public string Author { get; set; }

        public string Description { get; set; }

        public double Value { get; set; }

        public double? CurrentPosition { get; set; }

        public DateTime PublishDate { get; set; }
        public bool IsFinished { get; set; }
        public int Number { get; set; }

        public string DisplayName { get
            {
                return $"{Number} - {Name}";
            } 
        }
    }
}