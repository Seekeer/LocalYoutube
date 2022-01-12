using FileStore.Domain.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace FileStore.Infrastructure.Context
{
    public class SeasonMapping : IEntityTypeConfiguration<Season>
    {
        public void Configure(EntityTypeBuilder<Season> builder)
        {
            builder.HasKey(c => c.Id);

            builder.Property(c => c.Name);
            builder.Property(c => c.Number);
            builder.Property(c => c.IntroDuration);

            // 1 : N => Category : Books
            builder.HasMany(c => c.Files)
                .WithOne(b => b.Season)
                .HasForeignKey(b => b.SeasonId);

            builder.ToTable("Seasons");
        }
    }
    public class VideoFileExtendedInfoMapping : IEntityTypeConfiguration<VideoFileExtendedInfo>
    {
        public void Configure(EntityTypeBuilder<VideoFileExtendedInfo> builder)
        {
            builder.HasKey(c => c.Id);

            builder.Property(c => c.Cover);

            builder.HasOne(video => video.VideoFile)
                .WithOne(info => info.VideoFileExtendedInfo)
                .HasForeignKey<VideoFileExtendedInfo>(info => info.VideoFileId);

            builder.ToTable("VideoFileExtendedInfos");
        }
    }
    public class SeriesMapping : IEntityTypeConfiguration<Series>
    {
        public void Configure(EntityTypeBuilder<Series> builder)
        {
            builder.HasKey(c => c.Id);

            builder.Property(c => c.Name);
            builder.Property(c => c.IntroDuration);

            // 1 : N => Category : Books
            builder.HasMany(c => c.Files)
                .WithOne(b => b.Series)
                .HasForeignKey(b => b.SeriesId);
            builder.HasMany(c => c.Seasons)
                .WithOne(b => b.Series)
                .HasForeignKey(b => b.SeriesId);

            builder.ToTable("Series");
        }
    }
}