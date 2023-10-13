using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json.Schema;

namespace FileStore.Infrastructure.Repositories
{
    public class VideoFileRepository : FileRepositoryBase<VideoFile, VideoType>, IVideoFileRepository
    {
        public VideoFileRepository(VideoCatalogDbContext context) : base(context) { }

        public override async Task<IEnumerable<VideoFile>> SearchFileByType(VideoType type)
        {

            if(type == VideoType.FairyTale)
                return Db.VideoFiles.Where(x => x.Type == type).Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).OrderBy(x => x.Id);

            return Db.VideoFiles.Where(x => x.Type == type).Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).OrderBy(x => Guid.NewGuid());
        }

        protected override DbSet<VideoFile> GetFilesSet()
        {
            return Db.VideoFiles;
        }
    }
    public class AudioFileRepository : FileRepositoryBase<AudioFile, AudioType>, IAudioFileRepository
    {
        public AudioFileRepository(VideoCatalogDbContext context) : base(context) { }

        public override async Task<IEnumerable<AudioFile>> SearchFileByType(AudioType type)
        {
            return GetFilesSet().Where(x => x.Type == type).Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).OrderBy(x => Guid.NewGuid());
        }

        protected override DbSet<AudioFile> GetFilesSet()
        {
            return Db.AudioFiles;
        }
    }

    public abstract class FileRepositoryBase<T,V> : Repository<T>, IFileRepository<T,V>
        where T : DbFile
    {
        public FileRepositoryBase(VideoCatalogDbContext context) : base(context) { }

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
                return await SearchRandom(b => b.SeasonId == seasonId, count);
            else
                return await Search(file => file.SeasonId == seasonId && file.Id > startId);
        }

        public async Task<IEnumerable<T>> GetFilesBySeriesAsync(int seriesId, bool isRandom, int startId)
        {
            if(isRandom)
                return await SearchRandom(b => b.SeriesId == seriesId);
            else
                return await Search(file => file.SeriesId == seriesId && file.Id > startId);
        }

        public async Task<T> GetRandomFileBySeriesId(int seriesId)
        {
            var result = await SearchRandom(b => b.SeriesId == seriesId, 1);

            return result.FirstOrDefault();
        }

        public async Task<IEnumerable<T>> SearchByName(string searchedValue)
        {
            var files =  GetFilesSet().Where(x => 
                EF.Functions.Like(x.Name, $"%{searchedValue.ToLower()}%") || EF.Functions.Like(x.VideoFileExtendedInfo.Director, $"%{searchedValue.ToLower()}%") ).Include(x => x.VideoFileExtendedInfo).Include(x =>x.VideoFileUserInfos);

            return files;

            //_FileRepository.SearchRandom
        }


        public async Task<IEnumerable<T>> SearchFileWithSerieAsync(string searchedValue, bool isRandom, int resultCount)
        {
            var series = Db.Series.FirstOrDefault(x => EF.Functions.Like(x.Name, $"%{searchedValue.ToLower()}%"));

            var result = new List<T>();
            if (series == null)
                return result;

            var files = (GetFilesSet().Where(f => f.SeriesId == series.Id).ToList());

            if(!files.Any()) 
                return result;

            var skipMax = files.Count() - resultCount;

            result = files;
            if (isRandom)
            {
                result = files.OrderBy(x => Guid.NewGuid()).Take(resultCount).ToList();
            }
            else if (skipMax > 0)
            {
                var skip = (new Random()).Next(skipMax);
                result = files.OrderBy(x => x.Id).Skip(skip).Take(resultCount).ToList();
            }

            result.ToList().ForEach(
                x =>
                {
                    //Db.Entry(x).Reference(x => x.VideoFileExtendedInfo).Load();
                    x.SeriesId = series.Id;
                });

            return result;

        }
        public async Task<IEnumerable<T>> GetLatest(string userId)
        {
            var filesInfo = Db.FilesUserInfo.Where(x => x.UserId == userId).OrderByDescending(x => x.UpdatedDate).Take(10);

            var filesIds = filesInfo.Select(x => x.VideoFileId).ToList();
            var files = GetFilesSet().Where(x => filesIds.Contains(x.Id)).ToList();
            
            files = files.OrderByDescending(x => x.VideoFileUserInfos.FirstOrDefault(x => x.UserId == userId)?.UpdatedDate).ToList();

            return files;
        }

    }
}