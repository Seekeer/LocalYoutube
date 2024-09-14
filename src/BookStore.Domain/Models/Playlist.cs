using System;
using System.Collections.Generic;

namespace FileStore.Domain.Models
{
    public class Playlist : TrackUpdateCreateTimeEntity
    {
        public string Name { get; set; }

        /* EF Relations */
        public IList<DbFile> Files { get; set; } = new List<DbFile>();
    }
}