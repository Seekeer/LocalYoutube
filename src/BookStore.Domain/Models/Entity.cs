using System;

namespace FileStore.Domain.Models
{
    public abstract class Entity
    {
        public int Id { get; set; }

    }
    public abstract class TrackUpdateCreateTimeEntity : Entity
    {
        public DateTime UpdatedDate { get; set; } 
        public DateTime CreatedDate { get; set; }
    }
}