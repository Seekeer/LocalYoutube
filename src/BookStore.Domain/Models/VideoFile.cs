using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.IO;
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
        RutrackerDownloaded,
        ExternalVideo,
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
        public long TgId { get; set; }
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
        AudioBook,
        ChildMusic,
        ChildBook,
    }

    public class FileExtendedInfo : Entity
    {
        public DbFile DbFile { get; set; }
        public int VideoFileId { get; set; }

        public byte[] Cover { get; set; }
        public string Genres { get; set; }
        public int Year { get; set; }
        public string Description { get; set; }
        public string ExternalLink { get; set; }
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

    public abstract class DbFile : TrackUpdateCreateTimeEntity
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
        public bool IsDownloading { get; set; }
        public bool DoNotAutoFinish { get; set; }

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
        public double PreviousFilesDurationSeconds { get; set; }

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

        public abstract string GetUrl(AppConfig config);
    }

    public class VideoFile : DbFile
    {
        public VideoType Type { get; set; }
        public Quality Quality { get; set; }

        public bool IsOnlineFormat()
        {
            return Path.EndsWith("mp4") || Path.EndsWith("webm");
        }

        public override string GetUrl(AppConfig config)
        {
            if(IsOnlineFormat())
                return $"{config.UIUrl}/#/player?videoId={Id}&videosCount=1&isRandom=false&showDeleteButton=true"; 
            else
                return $"vlc://{config.APIUrl}/api/Files/getFileById?fileId={Id}"; 
        }
    }

    public class AudioFile : DbFile
    {
        public string Artist { get; set; }
        public AudioType Type { get; set; }

        public override string GetUrl(AppConfig config)
        {
            return $"{config.UIUrl}/#/player?videoId={Id}&videosCount=1&isRandom=false&showDeleteButton=true"; 
        }
    }
}