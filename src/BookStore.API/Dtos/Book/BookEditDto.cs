﻿using System;
using System.ComponentModel.DataAnnotations;

namespace FileStore.API.Dtos.File
{
    public interface IDtoId
    {
        int Id { get; set; }
        string Name { get; set; }
    }

    public class FileEditDto : IDtoId
    {
        [Key]
        public int Id { get; set; }

        [Required(ErrorMessage = "The field {0} is required")]
        public int SeriesId { get; set; }

        [Required(ErrorMessage = "The field {0} is required")]
        [StringLength(150, ErrorMessage = "The field {0} must be between {2} and {1} characters", MinimumLength = 2)]
        public string Name { get; set; }

        [Required(ErrorMessage = "The field {0} is required")]
        [StringLength(150, ErrorMessage = "The field {0} must be between {2} and {1} characters", MinimumLength = 2)]
        public string Author { get; set; }

        public string Description { get; set; }

        public double Value { get; set; }

        public DateTime PublishDate { get; set; }
    }
}