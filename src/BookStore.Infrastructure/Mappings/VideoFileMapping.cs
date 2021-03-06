using FileStore.Domain.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FileStore.Infrastructure.Context
{
    public class VideoFileMapping : IEntityTypeConfiguration<VideoFile>
    {
        public void Configure(EntityTypeBuilder<VideoFile> builder)
        {
            builder.Property(b => b.Name)
                .IsRequired();

            builder.Property(b => b.Number);
            builder.Property(b => b.Path);
            builder.Property(b => b.Quality);
            builder.Property(b => b.Origin);
            builder.Property(b => b.Type);
            builder.Property(b => b.Number);
            builder.Property(b => b.Duration);

            builder.ToTable("VideoFile");
        }
    }

    public class FileMapping : IEntityTypeConfiguration<DbFile>
    {
        public void Configure(EntityTypeBuilder<DbFile> builder)
        {
            builder.HasKey(b => b.Id);

            builder.Property(b => b.Name)
                .IsRequired();

            builder.Property(b => b.Number);
            builder.Property(b => b.Path);
            builder.Property(b => b.Origin);
            builder.Property(b => b.Number);
            builder.Property(b => b.Duration);

            builder.ToTable("DbFile");
        }
    }
    public class AudioFileMapping : IEntityTypeConfiguration<AudioFile>
    {
        public void Configure(EntityTypeBuilder<AudioFile> builder)
        {
            builder.Property(b => b.Name)
                .IsRequired();

            builder.Property(b => b.Number);
            builder.Property(b => b.Path);
            builder.Property(b => b.Origin);
            builder.Property(b => b.Type);
            builder.Property(b => b.Number);
            builder.Property(b => b.Duration);

            builder.ToTable("AudioFile");
        }
    }
}