using System;
using System.Collections.Generic;

namespace FileStore.Domain.Models
{
    public class Series : Entity
    {
        public string Name { get; set; }

        public Origin Origin { get; set; }
        public VideoType? Type { get; set; }
        public AudioType? AudioType { get; set; }
        public bool IsChild{ get; set; }
        public bool IsArchived{ get; set; }

        public TimeSpan IntroDuration { get; set; }

        /* EF Relations */
        public IEnumerable<DbFile> Files { get; set; }
        public IEnumerable<Season> Seasons { get; set; }
    }
}