using FileStore.Infrastructure.Context;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Text.Json;
using FileStore.Domain.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Infrastructure.Context;
using FileStore.Domain.Interfaces;

namespace MAUI.Services
{

    public class DbPathProvider : IFilePathProvider
    {
        private readonly IFileSystem fileSystem;

        public const string DATABASE_FILENAME = "localtube.db";

        public DbPathProvider(IFileSystem fileSystem)
        {
            this.fileSystem = fileSystem;
        }

        public string GetFilePath()
        {
            //return Path.Combine((Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)), DATABASE_FILENAME);

            var dbPath = Path.Combine(fileSystem.AppDataDirectory, DATABASE_FILENAME);

            Directory.CreateDirectory(fileSystem.AppDataDirectory);

            return dbPath;
        }
    }

    public static class MauiAppExtensions
    {
        public static async void SeedDatabase(this MauiApp mauiApp)
        {
            using var scope = mauiApp.Services.CreateScope();

            var dbContextFactory = scope.ServiceProvider.GetRequiredService<IDbContextFactory<SQLiteContext>>();

            try
            {
                using var dbContext = dbContextFactory.CreateDbContext();

                var pendingMigrations = MigrationsPending(dbContext);
                if (pendingMigrations)
                    dbContext.Database.Migrate();

                if (!dbContext.Series.Any())
                {
                    dbContext.Users.Add(new ApplicationUser { Id = MauiProgram.USER_ID });
                    dbContext.Series.Add(new Series { Id = MauiProgram.SERIES_ID });
                    dbContext.Seasons.Add(new Season { Id = MauiProgram.SEASON_ID, SeriesId = MauiProgram.SERIES_ID });
                    dbContext.SaveChanges();
                }
            }
            catch (Exception ex)
            {
            }
        }

        private static bool MigrationsPending(SQLiteContext dbContext)
        {
            // I'm not sure how this would work if the db didnt exist so for safety...
            try
            {
                return dbContext.Database.GetPendingMigrations().Any();
            }
            catch
            {
                return false;
            }
        }
    }

}
