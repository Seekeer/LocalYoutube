using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Linq.Expressions;
using System.Threading.Tasks;
using FileStore.Domain;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Infrastructure;
using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json.Schema;
using static FileStore.Infrastructure.Repositories.VideoFileRepository;

namespace FileStore.Infrastructure.Repositories
{
    public class DbFileRepository : FileRepositoryBase<DbFile, VideoType>, IDbFileRepository
    {
        public DbFileRepository(VideoCatalogDbContext context, AppConfig config) : base(context, config) { }

        public override Task<IEnumerable<DbFile>> SearchFileByType(VideoType type)
        {
            throw new NotImplementedException();
        }

        protected override DbSet<DbFile> GetFilesSet()
        {
            return Db.Files;
        }
    }

    public class VideoFileRepository : FileRepositoryBase<VideoFile, VideoType>, IVideoFileRepository
    {
        private readonly AppConfig _config;

        public VideoFileRepository(VideoCatalogDbContext context, AppConfig config) : base(context, config) { }

        public override async Task<IEnumerable<VideoFile>> SearchFileByType(VideoType type)
        {
            // ToList needed for some magic to remove duplicate records.
            if (type == VideoType.FairyTale)
                return Db.VideoFiles.Where(x => x.Type == type).Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).ToList().OrderBy(x => x.Id);

            return Db.VideoFiles.Where(x => x.Type == type).Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).ToList().OrderBy(x => Guid.NewGuid());
        }

        protected override DbSet<VideoFile> GetFilesSet()
        {
            return Db.VideoFiles;
        }
    }

    public class AudioFileRepository : FileRepositoryBase<AudioFile, AudioType>, IAudioFileRepository
    {
        public AudioFileRepository(VideoCatalogDbContext context, AppConfig config) : base(context, config) { }

        public override async Task<IEnumerable<AudioFile>> SearchFileByType(AudioType type)
        {
            return GetFilesSet().Where(x => x.Type == type).Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).OrderBy(x => Guid.NewGuid());
        }

        protected override DbSet<AudioFile> GetFilesSet()
        {
            return Db.AudioFiles;
        }
    }

    public abstract class FileRepositoryBase<T, V> : Repository<T>, IFileRepository<T, V>
        where T : DbFile
    {
        private readonly AppConfig _config;

        public FileRepositoryBase(VideoCatalogDbContext context, AppConfig config) : base(context) {
            _config = config;
        }

        public override async Task<List<T>> GetAll()
        {
            return await GetFilesSet().AsNoTracking().Include(b => b.Season).Include(b => b.Series)
                .OrderBy(b => b.Name)
                .ToListAsync();
        }

        protected abstract DbSet<T> GetFilesSet();
        public abstract Task<IEnumerable<T>> SearchFileByType(V type);

        public override async Task<T> GetById(int id)
        {
            var info = await GetFilesSet().AsNoTracking().Include(b => b.Season).Include(b => b.Series)
                .Include(file => file.VideoFileExtendedInfo).Include(file => file.VideoFileUserInfos)
                .Where(b => b.Id == id)
                .FirstOrDefaultAsync();

            return info;
        }

        public async Task<IEnumerable<T>> GetFilesBySeason(int seasonId, bool isRandom, int count, int startId)
        {
            if (isRandom)
                return await SearchRandomFile(b => b.SeasonId == seasonId, count);
            else
            {
                var result = await SearchFile(file => file.SeasonId == seasonId && file.Id > startId);
                return OrderByNumber(result);
            }
        }

        public async Task<IEnumerable<T>> GetFilesBySeriesAsync(int seriesId, int count, bool isRandom, int startId)
        {
            if(isRandom)
                return await SearchRandomFile(b => b.SeriesId == seriesId, count);
            else
            {
                var result = (await SearchFile(file => file.SeriesId == seriesId && file.Id > startId));
                return OrderByNumber(result).Take(count);
            }
        }

        private IEnumerable<T> OrderByNumber(IEnumerable<T> result)
        {
            return result.OrderBy(x => x.Number).ThenBy(x => x.Id);
        }

        public async Task<T> GetRandomFileBySeriesId(int seriesId)
        {
            var result = await SearchRandomFile(b => b.SeriesId == seriesId, 1);

            return result.FirstOrDefault();
        }

        private async Task<IEnumerable<T>> SearchRandomFile(Expression<Func<T, bool>> predicate, int resultCount = 10)
        {
            return (await base.SearchRandom(predicate, resultCount)).Where(x => !x.NeedToDelete);
        }

        private async Task<IEnumerable<T>> SearchFile(Expression<Func<T, bool>> predicate)
        {
            var items =  (await base.SearchAsync(predicate)).Where(x => !x.NeedToDelete);

            Db.ChangeTracker.Clear();
            return items;
        }

        public async Task<IEnumerable<T>> SearchByName(string searchedValue)
        {
            var files =  GetFilesSet().Where(x => 
                EF.Functions.Like(x.Name, $"%{searchedValue.ToLower()}%") || EF.Functions.Like(x.VideoFileExtendedInfo.Director, $"%{searchedValue.ToLower()}%") ).Include(x => x.VideoFileExtendedInfo).Include(x =>x.VideoFileUserInfos);

            return files;
        }

        public async Task<IEnumerable<T>> GetLatest(string userId, int count)
        {
            var filesInfo = Db.FilesUserInfo.Where(x => x.UserId == userId).OrderByDescending(x => x.UpdatedDate).Take(count);

            var filesIds = filesInfo.Select(x => x.VideoFileId).ToList();
            var files = GetFilesSet().Where(x => filesIds.Contains(x.Id)).ToList();
            
            files = files.OrderByDescending(x => x.VideoFileUserInfos.FirstOrDefault(x => x.UserId == userId)?.UpdatedDate).ToList();

            return files;
        }

        public void RemoveFileCompletely(int fileId)
        {
            var fileToDelete = Db.Files.FirstOrDefault(x => x.Id == fileId);
            Db.Files.Remove(fileToDelete);
            Db.SaveChanges();
        }

        public void MarkFileToDelete(T file)
        {
            file.NeedToDelete = true;
            Db.Attach(file);
            Db.Update(file);
            Db.SaveChanges();
        }

        public async Task<bool> MoveToSerie(int fileId, int serieId)
        {
            var file = await GetById(fileId);

            var season = Db.Seasons.FirstOrDefault(x => x.SeriesId == file.SeriesId);

            Db.Attach(file);

            file.SeriesId = serieId;
            file.SeasonId = season.Id;

            Db.SaveChanges();

            return true;
        }

        public async Task<bool> MoveToSeason(int fileId, int seasonId)
        {
            var file = await GetFilesSet().FirstOrDefaultAsync(x => x.Id == fileId);

            var oldSeasonId = file.SeasonId;
            var season = await Db.Seasons.Include(x => x.Series).FirstOrDefaultAsync(x => x.Id == seasonId);

            Db.Attach(file);
            file.SeasonId = seasonId;
            file.SeriesId = season.SeriesId;

            if(file is VideoFile)
            {
                (file as VideoFile).Type = season.Series.Type.Value;
            }

            await Db.SaveChangesAsync();

            var oldSeasonFiles = await Db.Files.CountAsync(x => x.SeasonId == oldSeasonId);
            if (oldSeasonFiles == 0)
            {
                var oldSeason = await Db.Seasons.FirstOrDefaultAsync(x => x.Id == oldSeasonId);
                Db.Seasons.Remove(oldSeason);
                await Db.SaveChangesAsync();
            }

            return true;
        }

        public async Task<IEnumerable<T>> GetNew(int count)
        {
            var files = new List<T>();

            var taken = 0;
            do
            {
                var newFiles = DbSet
                    .Include(x => x.Series).Include(x => x.VideoFileExtendedInfo)
                    .Where(x => x.Series.Type != VideoType.ChildEpisode && !x.NeedToDelete).OrderByDescending(x => x.Id)
                    .Skip(taken)
                    .Take(count);
                taken += count;

                foreach (var file in newFiles)
                {
                    NLog.LogManager.GetCurrentClassLogger().Info($"File {file.Id}");

                    var filesWithSeasonCount = files.Count(x => x.SeasonId == file.SeasonId);
                    NLog.LogManager.GetCurrentClassLogger().Info($"filesWithSeasonCount {filesWithSeasonCount} finished: {file.IsFinished}");
                    if (filesWithSeasonCount < _config.MaxSameSeasonInNewResponse && !file.IsFinished)
                        files.Add(file);

                    if (files.Count == count)
                        break;
                }
            }
            while (files.Count < count);


            return files;
        }

        public async Task<bool> Any(Expression<Func<T, bool>> predicate)
        {
            return DbSet.Any(predicate);
        }

    }
}