using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Microsoft.EntityFrameworkCore;

namespace Infrastructure.Context
{
    public class DbContextMigrator
    {
        private readonly VideoCatalogDbContext _sourceContext;
        private readonly SQLiteContext _targetContext;

        public async static Task Migrate()
        {
            var sourceOptions = new DbContextOptionsBuilder<VideoCatalogDbContext>()
                .UseSqlServer("Server=DESKTOP-VJO7P7P;Database=FileStore;Encrypt=False;Trusted_Connection=True;MultipleActiveResultSets=true;Connection Timeout=3600")
                .Options;

            var targetOptions = new DbContextOptionsBuilder<SQLiteContext>()
                .UseSqlite("Data Source=YourTargetDatabase.db")
                .Options;

            using var targetContext = new SQLiteContext(targetOptions);
            using var sourceContext = new VideoCatalogDbContext(sourceOptions);

            var migrator = new DbContextMigrator(sourceContext, targetContext);
            await migrator.MigrateAsync();
        }

        public DbContextMigrator(VideoCatalogDbContext sourceContext, SQLiteContext targetContext)
        {
            _sourceContext = sourceContext ?? throw new ArgumentNullException(nameof(sourceContext));
            _targetContext = targetContext ?? throw new ArgumentNullException(nameof(targetContext));
        }

        public async Task MigrateAsync()
        {
            // Ensure the target database is created
            await _targetContext.Database.EnsureDeletedAsync();
            await _targetContext.Database.EnsureCreatedAsync();

            // Migrate data for each DbSet in the correct order to respect relationships
            await MigrateTableAsync(_sourceContext.Users, _targetContext.Users);
            await MigrateTableAsync(_sourceContext.Series, _targetContext.Series);
            await MigrateTableAsync(_sourceContext.Seasons, _targetContext.Seasons);
            await MigrateTableAsync(_sourceContext.AudioFiles, _targetContext.AudioFiles);
            await MigrateTableAsync(_sourceContext.VideoFiles, _targetContext.VideoFiles);
            //await MigrateTableAsync(_sourceContext.Files, _targetContext.Files);RemoveOrphanedFileExtendedInfosAsync()

            //await RemoveOrphanedFileExtendedInfosAsync();
            //await MigrateFileUserInfoAsync();

            await MigrateTableAsync(_sourceContext.FilesUserInfo, _targetContext.FilesUserInfo);
            await MigrateTableAsync(_sourceContext.FilesInfo, _targetContext.FilesInfo);
            await MigrateTableAsync(_sourceContext.CoversInfo, _targetContext.CoversInfo);

            await MigrateTableAsync(_sourceContext.FileMarks, _targetContext.FileMarks);
            await MigrateTableAsync(_sourceContext.Playlists, _targetContext.Playlists);
            await MigrateTableAsync(_sourceContext.PlaylistItems, _targetContext.PlaylistItems);
            await MigrateTableAsync(_sourceContext.ExternalVideoSource, _targetContext.ExternalVideoSource);
            await MigrateTableAsync(_sourceContext.RefreshTokens, _targetContext.RefreshTokens);

            // Save changes to the target context
            await _targetContext.SaveChangesAsync();

            Console.WriteLine("Migration completed successfully.");
        }
        private async Task RemoveOrphanedFileExtendedInfosAsync()
        {
            // Find all FileExtendedInfo entries where the associated DbFile does not exist
            var orphanedInfos = await _targetContext.FilesInfo
                .Where(info => !_targetContext.Files.Any(file => file.Id == info.VideoFileId))
                .ToListAsync();

            if (orphanedInfos.Any())
            {
                // Remove the orphaned entries
                _targetContext.FilesInfo.RemoveRange(orphanedInfos);
                await _targetContext.SaveChangesAsync();

                Console.WriteLine($"Removed {orphanedInfos.Count} orphaned FileExtendedInfo entries.");
            }
            else
            {
                Console.WriteLine("No orphaned FileExtendedInfo entries found.");
            }
        }
        private async Task<List<FileUserInfo>> GetValidFileUserInfosAsync()
        {
            var validUserIds = await _targetContext.Users.Select(u => u.Id).ToListAsync();
            var validVideoFileIds = await _targetContext.VideoFiles.Select(v => v.Id).ToListAsync();
            var validAudioFileIds = await _targetContext.AudioFiles.Select(v => v.Id).ToListAsync();

            // Filter FileUserInfo entries where both foreign keys are valid
            var validFileUserInfos22 =  _sourceContext.FilesUserInfo
                //.AsNoTracking()
                //.Include(x => x.DbFile)
                .First(fui =>
                    //validUserIds.Contains(fui.UserId) 
                    //&& 
                    !validVideoFileIds.Contains(fui.VideoFileId)
                );

            // Filter FileUserInfo entries where both foreign keys are valid
            var validFileUserInfos = await _sourceContext.FilesUserInfo
                //.AsNoTracking()
                .Where(fui => 
                    //validUserIds.Contains(fui.UserId) 
                    //&& 
                    !validVideoFileIds.Contains(fui.VideoFileId)
                    &&
                    !validAudioFileIds.Contains(fui.VideoFileId)
                )
                .ToListAsync();

            return validFileUserInfos;
        }

        private async Task MigrateFileUserInfoAsync()
        {
            // Get valid FileUserInfo entries
            var validFileUserInfos = await GetValidFileUserInfosAsync();

            if (validFileUserInfos.Any())
            {
                // Remove existing entries in the target context
                var existing = await _targetContext.FilesUserInfo.ToListAsync();
                _targetContext.FilesUserInfo.RemoveRange(existing);
                await _targetContext.SaveChangesAsync();

                // Add valid entries to the target context
                await _targetContext.FilesUserInfo.AddRangeAsync(validFileUserInfos);
                await _targetContext.SaveChangesAsync();

                Console.WriteLine($"Migrated {validFileUserInfos.Count} valid FileUserInfo entries.");
            }
            else
            {
                Console.WriteLine("No valid FileUserInfo entries to migrate.");
            }
        }

        private async Task MigrateTableAsync<T>(DbSet<T> source, DbSet<T> target) where T : class
        {
            if (await source.AnyAsync())
            {
                var existing = await target.ToListAsync();
                target.RemoveRange(existing);
                await _targetContext.SaveChangesAsync();

                // Fetch data from the source context
                var data = await source.AsNoTracking().ToListAsync();

                // Add data to the target context
                await target.AddRangeAsync(data);

                await _targetContext.SaveChangesAsync();
            }
        }
        //private async Task MigrateTableAsync2<T>(DbSet<T> source, DbSet<T> target) where T : class
        //{
        //    if (await source.AnyAsync())
        //    {
        //        // Fetch data from the source context
        //        var data = await source.AsNoTracking().ToListAsync();

        //        foreach (var entity in data)
        //        {
        //            // Check if the entity already exists in the target context
        //            var primaryKey = _targetContext.Entry(entity).Property("Id").CurrentValue;
        //            var exists = await target.FindAsync(primaryKey);

        //            var existing = _targetContext.
        //            if (exists == null)
        //            {
        //                // Add the entity only if it doesn't already exist
        //                await target.AddAsync(entity);
        //            }
        //            else
        //            {

        //            }
        //        }

        //        // Save changes to the target context
        //        await _targetContext.SaveChangesAsync();
        //    }
        //}
    }
}
