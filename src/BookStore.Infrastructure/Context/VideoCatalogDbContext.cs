using System;
using System.Linq;
using FileStore.Domain.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using System.Threading.Tasks;
using System.Threading;
using Microsoft.Extensions.DependencyInjection;

namespace FileStore.Infrastructure.Context
{

    public static class DbExtension
    {
        public static VideoCatalogDbContext CreateDb(this IServiceScopeFactory factory)
        {
            return factory.CreateScope().ServiceProvider.GetRequiredService<FileStore.Infrastructure.Context.VideoCatalogDbContext>();
        }
    }

    public class VideoCatalogContextFactory : IDesignTimeDbContextFactory<VideoCatalogDbContext>
    {
        public VideoCatalogDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<VideoCatalogDbContext>();
            optionsBuilder.UseSqlServer("Server=localhost;Database=FileStore;Encrypt=False;Trusted_Connection=True;");

            return new VideoCatalogDbContext(optionsBuilder.Options);
        }

        public static VideoCatalogDbContext CreateSecondDb()
        {
            var optionsBuilder = new DbContextOptionsBuilder<VideoCatalogDbContext>();
            optionsBuilder.UseSqlServer("Server=localhost;Database=FileStore_backup;Encrypt=False;Trusted_Connection=True;");

            return new VideoCatalogDbContext(optionsBuilder.Options);
        }
    }

    // cd .\src\BookStore.Infrastructure\
    // dotnet ef migrations add ShowLatest
    //  dotnet ef database update
    public class VideoCatalogDbContext : IdentityUserContext<ApplicationUser>
    {
        public VideoCatalogDbContext(DbContextOptions options) : base(options)
        {
            this.ChangeTracker.LazyLoadingEnabled = false;
        }

        public DbSet<UserRefreshTokens> RefreshTokens { get; set; }
        public DbSet<Season> Seasons { get; set; }
        public DbSet<AudioFile> AudioFiles { get; set; }
        public DbSet<VideoFile> VideoFiles { get; set; }
        public DbSet<DbFile> Files { get; set; }
        public DbSet<FileExtendedInfo> FilesInfo { get; set; }
        public DbSet<FileUserInfo> FilesUserInfo { get; set; }
        public DbSet<FileMark> FileMarks { get; set; }

        public DbSet<Series> Series { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            //modelBuilder.Entity<VideoFile>(entity =>
            //{
            //    entity.HasOne(video => video.VideoFileExtendedInfo)
            //        .WithOne(info => info.VideoFile)
            //        .HasForeignKey<VideoFileExtendedInfo>(info => info.VideoFileId);
            //});

            modelBuilder.Entity<VideoFile>().Navigation(e => e.VideoFileExtendedInfo).AutoInclude();
            modelBuilder.Entity<VideoFile>().Navigation(e => e.VideoFileUserInfos).AutoInclude();
            modelBuilder.Entity<AudioFile>().Navigation(e => e.VideoFileExtendedInfo).AutoInclude();
            modelBuilder.Entity<AudioFile>().Navigation(e => e.VideoFileUserInfos).AutoInclude();
            //modelBuilder.Entity<FileUserInfo>().Navigation(e => e.User).AutoInclude();

            modelBuilder.ApplyConfigurationsFromAssembly(typeof(VideoCatalogDbContext).Assembly);

            foreach (var relationship in modelBuilder.Model.GetEntityTypes()
                .SelectMany(e => e.GetForeignKeys())) relationship.DeleteBehavior = DeleteBehavior.ClientSetNull;

            //SeedData(modelBuilder);

            base.OnModelCreating(modelBuilder);
        }

        public override int SaveChanges()
        {
            //UpdateTimeStamps();

            return base.SaveChanges();
        }

        public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
        {
            UpdateTimeStamps();

            return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
        }

        private void UpdateTimeStamps()
        {
            try
            {
                var entries = ChangeTracker
                    .Entries()
                    .Where(e => e.Entity is TrackUpdateCreateTimeEntity && (
                            e.State == EntityState.Added
                            || e.State == EntityState.Modified));

                foreach (var entityEntry in entries)
                {
                    if (entityEntry.State == EntityState.Added)
                        ((TrackUpdateCreateTimeEntity)entityEntry.Entity).CreatedDate = DateTime.UtcNow;

                    ((TrackUpdateCreateTimeEntity)entityEntry.Entity).UpdatedDate = DateTime.UtcNow;
                }
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }
        }

        //private void SeedData(ModelBuilder modelBuilder)
        //{
        //    modelBuilder.Entity<User>().HasData(
        //        (new User { Id = 1, Username = "dimtim", Password = "hehe", ExpireAt = DateTime.MaxValue })
        //    );
        //}
    }
}