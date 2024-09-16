using System;
using System.Collections.Generic;

namespace FileStore.Domain.Models
{
    public class Playlist : TrackUpdateCreateTimeEntity
    {
        public string Name { get; set; }

        /* EF Relations */
        public IList<PlaylistItem> Items { get; set; } = new List<PlaylistItem>();
    }

    public class PlaylistItem : TrackUpdateCreateTimeEntity
    {
        public DbFile File { get; set; }
        public int Index { get; set; }
    }
}