using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
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
        [IsOnlineVideoAttribute]
        Art,
        [IsOnlineVideoAttribute]
        AdultEpisode,
        [IsOnlineVideoAttribute]
        Courses,
        Downloaded,
        Youtube,
        EoT,
        Special
    }
    [System.AttributeUsage(AttributeTargets.Field, AllowMultiple = false, Inherited = true)]
    public sealed class IsOnlineVideoAttribute : Attribute
    {
        public IsOnlineVideoAttribute()
        {
        }

    }

    public class ApplicationUser : IdentityUser
    {
        public IList<FileUserInfo> VideoFileUserInfos { get; set; } = new List<FileUserInfo>();
    }

    public class UserRefreshTokens : Entity
    {
        [Required]
        public string UserName { get; set; }
        [Required]
        public string RefreshToken { get; set; }
        public bool IsActive { get; set; } = true;
    }

    public enum AudioType
    {
        Unknown,
        Music,
        Podcast,
        EoT,
        FairyTale,
        Lessons,
        RussianBook,
        ForeignBook
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

    public class FileUserInfo : TrackUpdateCreateTimeEntity
    {
        public DbFile DbFile { get; set; }
        public int VideoFileId { get; set; }

        public ApplicationUser User { get; set; }
        public string UserId { get; set; }

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
        public bool IsBackedup{ get; set; }
        public bool NeedToDelete{ get; set; }

        public IList<FileUserInfo> VideoFileUserInfos { get; set; } = new List<FileUserInfo>();
        public IList<FileMark> Marks { get; set; } = new List<FileMark>();
        public FileExtendedInfo VideoFileExtendedInfo { get; set; } = new FileExtendedInfo();

        [NotMapped]
        public string CurrentUserId { get; set; }
        [NotMapped]
        public FileUserInfo VideoFileUserInfo
        {
            get
            {
                if (VideoFileUserInfos == null)
                    return new FileUserInfo();

                return VideoFileUserInfos.FirstOrDefault(x => x.UserId == CurrentUserId) ?? new FileUserInfo() ;
            }
        }

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
        public double CurrentPosition
        {
            get
            {
                return VideoFileUserInfo?.Position ?? 0;
            }
        }

        [NotMapped]
        public virtual bool IsFinished
        {
            get
            {
                if (VideoFileUserInfo == null || Duration == TimeSpan.Zero)
                    return false;
                //return true;
                if (VideoFileUserInfo.Position > 0 && Duration == TimeSpan.Zero)
                    return true;

                var watchedTime = TimeSpan.FromSeconds(VideoFileUserInfo.Position);

                if ((this as VideoFile)?.Type == VideoType.Courses)
                    return (Duration - watchedTime) < TimeSpan.FromSeconds(10);

                var watchedPercent = (watchedTime) / Duration;

                return watchedPercent > 0.9;

            }
        }

        [NotMapped]
        public bool IsSupportedWebPlayer
        {
            get
            {
                return Path.EndsWith("mp4") || Path.EndsWith(".m4v");
            }
        }

        public override string ToString()
        {
            return Name;
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