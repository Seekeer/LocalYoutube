using FileStore.Domain.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FileStore.Domain.Dtos
{
    public class PositionDTO : UpdateTimeDTO
    {
        public double Position { get; set; }
    }

    public class UpdateTimeDTO
    {
        public DateTime UpdatedDate { get; set; } = DateTime.UtcNow;
    }
}
