using System;
using System.Collections.Generic;

namespace FileStore.Domain.Models
{
    public class Series : Entity
    {
        public string Name { get; set; }

        public TimeSpan IntroDuration { get; set; }

        /* EF Relations */
        public IEnumerable<DbFile> Files { get; set; }
        public IEnumerable<Season> Seasons { get; set; }
    }
}