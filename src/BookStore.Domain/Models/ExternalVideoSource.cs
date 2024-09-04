namespace FileStore.Domain.Models
{
    public enum DownloadType
    {
        Youtube = 0,
        VK = 1,
        Common = 2,
        Rossaprimavera = 3,
    }

    public class ExternalVideoSource : TrackUpdateCreateTimeEntity
    {
        public string ChannelId { get; set; }
        public string PlaylistId { get; set; }

        public int SeriesId { get; set; }
        public int SeasonId { get; set; }
        public DownloadType Network { get; internal set; }
    }
}
