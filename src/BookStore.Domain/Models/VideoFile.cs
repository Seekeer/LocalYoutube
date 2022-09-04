using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;

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
        [IsOnlineVideoAttribute]
        Animation,
        [IsOnlineVideoAttribute]
        ChildEpisode,
        [IsOnlineVideoAttribute]
        FairyTale,
        Lessons, 
        Art,
        [IsOnlineVideoAttribute]
        AdultEpisode,
        [IsOnlineVideoAttribute]
        Courses,
        Downloaded,
        Youtube
    }
    [System.AttributeUsage(AttributeTargets.Field, AllowMultiple = false, Inherited = true)]
    public sealed class IsOnlineVideoAttribute : Attribute
    {
        public IsOnlineVideoAttribute()
        {
        }

        public static bool HasAttribute<T>(T value)
            where T : System.Enum
        {
            var valuesWithAttribute = GetValuesWithAttribute<T>();

            return valuesWithAttribute.Any(x => EqualityComparer<T>.Default.Equals(x, value));
        }

        public static IEnumerable<T> GetValuesWithAttribute<T>()
        {
            var values = (T[])Enum.GetValues(typeof(T));

            var result = new List<T>();
            foreach (var value in (T[])Enum.GetValues(typeof(T)))
            {
                var memberInfos = typeof(T).GetMember(value.ToString());
                var enumValueMemberInfo = memberInfos.FirstOrDefault(m => m.DeclaringType == typeof(T));
                var valueAttributes = enumValueMemberInfo.GetCustomAttributes(typeof(IsOnlineVideoAttribute), false);

                if (!valueAttributes.Any())
                    continue;

                result.Add(value);
            }

            return result;
        }
    }

    public enum AudioType
    {
        Unknown,
        Music,
        Podcast,
        EoT,
        FairyTale,
        Lessons
    }

    public class FileExtendedInfo : Entity
    {
        public DbFile DbFile { get; set; }
        public int VideoFileId { get; set; }

        public byte[] Cover { get; set; }
        public string Genres { get; set; }
        public int Year { get; set; }
        public string Description { get; set; }
        public int RutrackerId { get; set; }
        public string Director { get; set; }
    }

    public class FileUserInfo : Entity
    {
        public DbFile DbFile { get; set; }
        public int VideoFileId { get; set; }

        public double Position { get; set; }
        public double Rating { get; set; }
    }

    public abstract class DbFile : Entity
    {
        public string Path { get; set; }
        public string Name { get; set; }
        public Origin Origin { get; set; }
        public TimeSpan Duration { get; set; }

        /// <summary>
        /// Series properties
        /// </summary>
        public int Number { get; set; }
        public int SeasonId { get; set; }
        public int SeriesId { get; set; }
        /* EF Relation */
        public Season Season { get; set; }
        public Series Series { get; set; }

        public FileUserInfo VideoFileUserInfo { get; set; } = new FileUserInfo();
        public FileExtendedInfo VideoFileExtendedInfo { get; set; } = new FileExtendedInfo();

        [NotMapped]
        public byte[] Cover
        {
            get
            {
                return VideoFileExtendedInfo?.Cover;
            }
        }

        [NotMapped]
        public string Description
        {
            get
            {
                return VideoFileExtendedInfo.Description;
            }
        }

        [NotMapped]
        public int Year
        {
            get
            {
                return VideoFileExtendedInfo.Year;
            }
        }

        [NotMapped]
        public string Director
        {
            get
            {
                return VideoFileExtendedInfo.Director;
            }
        }

        [NotMapped]
        public string Genres
        {
            get
            {
                return VideoFileExtendedInfo.Genres;
            }
        }

        [NotMapped]
        public double? CurrentPosition
        {
            get
            {
                return VideoFileUserInfo?.Position;
            }
        }

        [NotMapped]
        public bool IsFinished
        {
            get
            {
                if (VideoFileUserInfo == null || Duration > TimeSpan.Zero)
                    return false;
                //return true;
                var watchedTime = TimeSpan.FromSeconds(VideoFileUserInfo.Position);

                if ((this as VideoFile)?.Type == VideoType.Courses)
                    return (Duration - watchedTime) < TimeSpan.FromSeconds(10);

                var watchedPercent = (watchedTime) / Duration;

                return watchedPercent > 0.9;

            }
        }
    }

    public class VideoFile : DbFile
    {
        public VideoType Type { get; set; }
        public Quality Quality { get; set; }
        public bool IsDownloading { get; set; }
    }

    public class AudioFile : DbFile
    {
        public AudioType Type { get; set; }
    }
}