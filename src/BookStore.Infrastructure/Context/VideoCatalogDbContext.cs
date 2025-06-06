﻿using System;
using System.Linq;
using FileStore.Domain.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using System.Threading.Tasks;
using System.Threading;
using Microsoft.Extensions.DependencyInjection;
using static Microsoft.EntityFrameworkCore.DbLoggerCategory;
using Infrastructure.Context;

namespace FileStore.Infrastructure.Context
{

    public static class DbExtension
    {
        public static VideoCatalogDbContext CreateDb(this IServiceScopeFactory factory)
        {
            return factory.CreateScope().ServiceProvider.GetRequiredService<VideoCatalogDbContext>();
        }
    }

    public class VideoCatalogContextFactory : IDesignTimeDbContextFactory<VideoCatalogDbContext>
    {
        public VideoCatalogDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<VideoCatalogDbContext>();
            optionsBuilder.UseSqlServer("Server=DESKTOP-VJO7P7P;Database=FileStore;Encrypt=False;Trusted_Connection=True;MultipleActiveResultSets=true;Connection Timeout=3600;");

            return new VideoCatalogDbContext(optionsBuilder.Options);
        }

        public static VideoCatalogDbContext CreateSecondDb()
        {
            var optionsBuilder = new DbContextOptionsBuilder<VideoCatalogDbContext>();
            optionsBuilder.UseSqlServer("Server=localhost;Database=FileStore_backup;Encrypt=False;Trusted_Connection=True;");

            return new VideoCatalogDbContext(optionsBuilder.Options);
        }
    }

    // dotnet tool install --global dotnet-ef

    // cd .\src\BookStore.Infrastructure\
    // dotnet ef migrations add ShowLatest
    // dotnet ef migrations add ExternalServiceMapping --context VideoCatalogDbContext
    // dotnet ef database update --context VideoCatalogDbContext
    // dotnet ef migrations remove --force
    public class VideoCatalogDbContext : IdentityUserContext<ApplicationUser>
    {
        public VideoCatalogDbContext(DbContextOptions options) : base(options)
        {
            //this.ChangeTracker.LazyLoadingEnabled = false;
        }

        public DbSet<UserRefreshTokens> RefreshTokens { get; set; }
        public DbSet<Season> Seasons { get; set; }
        public DbSet<AudioFile> AudioFiles { get; set; }
        public DbSet<VideoFile> VideoFiles { get; set; }
        public DbSet<DbFile> Files { get; set; }
        public DbSet<FileExtendedInfo> FilesInfo { get; set; }
        public DbSet<CoverInfo> CoversInfo { get; set; }
        public DbSet<FileUserInfo> FilesUserInfo { get; set; }
        public DbSet<FileMark> FileMarks { get; set; }
        public DbSet<Playlist> Playlists { get; set; }
        public DbSet<PlaylistItem> PlaylistItems { get; set; }
        public DbSet<ExternalVideoSourceMapping> ExternalVideoSource { get; set; }

        public DbSet<Series> Series { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            //modelBuilder.Entity<VideoFile>(entity =>
            //{
            //    entity.HasOne(video => video.VideoFileExtendedInfo)
            //        .WithOne(info => info.VideoFile)
            //        .HasForeignKey<VideoFileExtendedInfo>(info => info.VideoFileId);
            //});
            
            modelBuilder.Entity<DbFile>().HasQueryFilter(u => !u.NeedToDelete);

            modelBuilder.Entity<VideoFile>().Navigation(e => e.VideoFileExtendedInfo).AutoInclude();
            modelBuilder.Entity<VideoFile>().Navigation(e => e.VideoFileUserInfos).AutoInclude();
            modelBuilder.Entity<AudioFile>().Navigation(e => e.VideoFileExtendedInfo).AutoInclude();
            modelBuilder.Entity<AudioFile>().Navigation(e => e.VideoFileUserInfos).AutoInclude();
            //modelBuilder.Entity<FileUserInfo>().Navigation(e => e.User).AutoInclude();

            modelBuilder.ApplyConfigurationsFromAssembly(typeof(VideoCatalogDbContext).Assembly);

            foreach (var relationship in modelBuilder.Model.GetEntityTypes()
                .SelectMany(e => e.GetForeignKeys())) relationship.DeleteBehavior = DeleteBehavior.Cascade;

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