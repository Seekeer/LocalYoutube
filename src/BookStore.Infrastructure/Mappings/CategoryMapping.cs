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
            builder.Property(c => c.IsOrderMatter);

            // 1 : N => Category : Books
            builder.HasMany(c => c.Files)
                .WithOne(b => b.Season)
                .HasForeignKey(b => b.SeasonId);

            builder.ToTable("Seasons");
        }
    }
    public class VideoFileExtendedInfoMapping : IEntityTypeConfiguration<FileExtendedInfo>
    {
        public void Configure(EntityTypeBuilder<FileExtendedInfo> builder)
        {
            builder.HasKey(c => c.Id);

            //builder.Property(c => c.Cover);

            builder.HasOne(video => video.DbFile)
                .WithOne(info => info.VideoFileExtendedInfo)
                .HasForeignKey<FileExtendedInfo>(info => info.VideoFileId)
                ;

            builder.ToTable("VideoFileExtendedInfos");
        }
    }
    public class CoverInfoMapping : IEntityTypeConfiguration<CoverInfo>
    {
        public void Configure(EntityTypeBuilder<CoverInfo> builder)
        {
            builder.HasKey(c => c.Id);

            builder.Property(c => c.Cover);

            builder.HasOne(video => video.DbFile)
                .WithOne(info => info.CoverInfo)
                .HasForeignKey<CoverInfo>(info => info.VideoFileId)
                ;

            builder.ToTable("VideoFileCoverInfo");
        }
    }
    public class VideoFileUserInfoMapping : IEntityTypeConfiguration<FileUserInfo>
    {
        public void Configure(EntityTypeBuilder<FileUserInfo> builder)
        {
            builder.HasKey(c => c.Id);

            builder.Property(c => c.Rating);
            builder.Property(c => c.Position);

            builder.HasOne<ApplicationUser>(e => e.User)
                .WithMany(b => b.VideoFileUserInfos)
                .HasForeignKey(e => e.UserId)
                ;
            builder.HasOne<DbFile>(e => e.DbFile)
                .WithMany(b => b.VideoFileUserInfos)
                .HasForeignKey(e => e.VideoFileId)
                ;

            builder.ToTable("VideoFileUserInfos");
        }
    }
    public class SeriesMapping : IEntityTypeConfiguration<Series>
    {
        public void Configure(EntityTypeBuilder<Series> builder)
        {
            builder.HasKey(c => c.Id);

            builder.Property(c => c.Name);
            builder.Property(c => c.IntroDuration);
            builder.Property(c => c.Origin);
            builder.Property(c => c.IsChild);
            builder.Property(c => c.IsOrderMatter);
            builder.Property(c => c.Type);

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