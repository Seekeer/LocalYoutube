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
    public enum Origin
    {
        Unknown,
        Soviet,
        Russian,
        Foreign
    }
    public enum VideoType
    {
        Unknown,
        Film,
        Animation,
        Episode,
        FairyTale
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
        public VideoType Type { get; set; }
        public Origin Origin { get; set; }
        public Quality Quality { get; set; }
        public TimeSpan Duration { get; set; }

        public double Rating { get; set; }

        /// <summary>
        /// Series properties
        /// </summary>
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