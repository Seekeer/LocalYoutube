﻿using System;

namespace Dtos
{

    public interface IDtoId
    {
        int Id { get; set; }
        string Name { get; set; }
    }

    public class DtoIdBase : IDtoId
    {
        public int Id { get; set; }
        public string Name { get; set; }
    }

    public class VideoFileResultDto : DtoIdBase
    {

        public int SeriesId { get; set; }
        public int SeasonId { get; set; }

        public string SeriesName { get; set; }

        public string Author { get; set; }

        public string Description { get; set; }
        public string Director { get; set; }
        public int Year { get; set; }
        public TimeSpan Duration { get; set; }
        public double PreviousFilesDurationSeconds { get; set; }

        public int DurationMinutes
        {
            get
            {
                return (int)Duration.TotalMinutes;
            }
        }
        public string Genres { get; set; }

        public double Value { get; set; }

        public double? CurrentPosition { get; set; }

        public DateTime PublishDate { get; set; }
        public bool IsFinished { get; set; }
        public bool IsSupportedWebPlayer{ get; set; }
        public int Number { get; set; }

        public string DisplayName { get
            {
                return $"{Name}";
                //return $"{Number} - {Name}";
            } 
        }

        public string CoverURL { get; set; }
    }

}