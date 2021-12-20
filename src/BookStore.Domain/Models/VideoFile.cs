using System;
using System.ComponentModel.DataAnnotations.Schema;

namespace FileStore.Domain.Models
{
    public enum Quality
    {
        Unknown,
        FullHD,
        HD,
        SD,
    }
    public enum Source
    {
        Unknown,
        Soviet,
        Russian,
        Foreign
    }
    public enum Type
    {
        Film,
        Episode
    }

    public class VideoFileExtendedInfo : Entity
    {
        public VideoFile VideoFile { get; set; }
        public int VideoFileId { get; set; }

        public byte[] Cover { get; set; }
    }

    public class VideoFile : Entity
    {
        public string Path { get; set; }
        public string Name { get; set; }
        public Type Type { get; set; }
        public Source Source { get; set; }
        public Quality Quality { get; set; }
        public int Number { get; set; }
        public int SeasonId { get; set; }
        public int SeriesId { get; set; }

        /* EF Relation */
        public Season Season { get; set; }
        public Series Series { get; set; }

        public VideoFileExtendedInfo VideoFileExtendedInfo { get; set; }
        [NotMapped]
        public byte[] Cover { 
            get
            {
                return VideoFileExtendedInfo.Cover;
            }
        }

    }
}