using System;
using System.Collections.Generic;

namespace FileStore.Domain.Models
{
    public class Season : Entity
    {
        public int Number{ get; set; }
        public string Name { get; set; }
        public TimeSpan IntroDuration { get; set; }

        /* EF Relations */
        public IEnumerable<VideoFile> Files { get; set; }
        public int SeriesId { get; set; }
        public Series Series { get; set; }
    }
}