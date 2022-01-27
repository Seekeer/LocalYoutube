using System.Linq;
using FileStore.Domain.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace FileStore.Infrastructure.Context
{
    public class VideoCatalogContextFactory : IDesignTimeDbContextFactory<VideoCatalogDbContext>
    {
        public VideoCatalogDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<VideoCatalogDbContext>();
            optionsBuilder.UseSqlServer("Server=localhost;Database=FileStore;Trusted_Connection=True;");

            return new VideoCatalogDbContext(optionsBuilder.Options);
        }
    }
    public class VideoCatalogDbContext : DbContext
    {
        public VideoCatalogDbContext(DbContextOptions options) : base(options) { }

        public DbSet<Season> Seasons { get; set; }
        public DbSet<VideoFile> Files { get; set; }
        public DbSet<VideoFileExtendedInfo> FilesInfo { get; set; }
        public DbSet<VideoFileUserInfo> FilesUserInfo { get; set; }
        public DbSet<Series> Series { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            //modelBuilder.Entity<VideoFile>(entity =>
            //{
            //    entity.HasOne(video => video.VideoFileExtendedInfo)
            //        .WithOne(info => info.VideoFile)
            //        .HasForeignKey<VideoFileExtendedInfo>(info => info.VideoFileId);
            //});

            modelBuilder.ApplyConfigurationsFromAssembly(typeof(VideoCatalogDbContext).Assembly);

            foreach (var relationship in modelBuilder.Model.GetEntityTypes()
                .SelectMany(e => e.GetForeignKeys())) relationship.DeleteBehavior = DeleteBehavior.ClientSetNull;

            base.OnModelCreating(modelBuilder);
        }
    }
}