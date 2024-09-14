using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using FileStore.Infrastructure.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Internal;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyModel;
using NUnit.Framework;
using System;
using System.Threading.Tasks;

namespace Core.Tests.DB
{
    public static class ServiceCollectionExtensions
    {
        public static async Task<IServiceCollection> AddServices(this IServiceCollection serviceCollection)
        {
            var connectionStr = "Server=localhost;Database=LocalTube_Test;Encrypt=False;Trusted_Connection=True;";
            var optionsBuilder = new DbContextOptionsBuilder<VideoCatalogDbContext>();
            optionsBuilder.UseSqlServer(connectionStr);

            var db = new VideoCatalogDbContext(optionsBuilder.Options);
            await db.Database.EnsureDeletedAsync();
            await db.Database.MigrateAsync();

            serviceCollection.AddTransient<IPlaylistRepository, PlaylistRepository>();
            serviceCollection.AddTransient<IVideoFileRepository, VideoFileRepository>();
            serviceCollection.AddTransient<ISeriesRepository, SeriesRepository>();
            serviceCollection.AddSingleton(db);

            return serviceCollection;
        }
    }

    internal class DBTest
    {
        protected static ServiceProvider serviceProvider;

        [OneTimeSetUp]
        public async Task CreateServiceProvider()
        {
            var serviceCollection = await new ServiceCollection().AddServices();
            serviceProvider = serviceCollection.BuildServiceProvider();

            SeedDb();
        }

        private void SeedDb()
        {
            var db = serviceProvider.GetService<VideoCatalogDbContext>();
            var serries = new Series { };
            db.Series.Add(serries);
            db.SaveChanges();

            var file = new VideoFile
            {
                Name = "name",
                Season = new Season { Series = serries },
                Series = serries
            };
            db.VideoFiles.Add(file);
            db.SaveChanges();

            var playlist = new Playlist {  };
            db.Playlists.Add(playlist);

            db.SaveChanges();
        }

    }
}