using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FileStore.Domain.Models
{
    public class FileMark : Entity
    {
        public int DbFileId { get; set; }
        public string UserId { get; set; }
        public double Position { get; set; }

    }
}
