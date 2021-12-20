using System.Collections.Generic;

namespace FileStore.Domain.Models
{
    public class Series : Entity
    {
        public string Name { get; set; }

        /* EF Relations */
        public IEnumerable<VideoFile> Files { get; set; }
        public IEnumerable<Season> Seasons { get; set; }
    }
}