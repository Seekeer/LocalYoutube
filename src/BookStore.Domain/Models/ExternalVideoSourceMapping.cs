using System;

namespace FileStore.Domain.Models
{
    public enum DownloadType
    {
        Youtube = 0,
        VK = 1,
        Common = 2,
        Rossaprimavera = 3,
        Mishka = 4,
    }

    public class ExternalVideoSourceMapping : TrackUpdateCreateTimeEntity
    {
        public string ChannelId { get; set; }
        public string ChannelName { get; set; }
        public string PlaylistId { get; set; }
        public bool CheckNewVideo { get; set; }

        public int SeriesId { get; set; }
        public int SeasonId { get; set; }
        public DownloadType Network { get; set; }
        public DateTime LastCheckDate { get; set; } = DateTime.UtcNow;

        //public int UserId { get; set; }

    }
}
