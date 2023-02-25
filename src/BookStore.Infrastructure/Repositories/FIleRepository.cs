using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Microsoft.EntityFrameworkCore;

namespace FileStore.Infrastructure.Repositories
{
    public class FileRepository : Repository<VideoFile>, IFileRepository
    {
        public FileRepository(VideoCatalogDbContext context) : base(context) { }

        public override async Task<List<VideoFile>> GetAll()
        {
            return await Db.VideoFiles.AsNoTracking().Include(b => b.Season).Include(b => b.Series)
                .OrderBy(b => b.Name)
                .ToListAsync();
        }

        public override async Task<VideoFile> GetById(int id)
        {
            var info = await Db.VideoFiles.AsNoTracking().Include(b => b.Season).Include(b => b.Series)
                .Include(file => file.VideoFileExtendedInfo).Include(file => file.VideoFileUserInfos)
                .Where(b => b.Id == id)
                .FirstOrDefaultAsync();

            return info;
        }


        public async Task<IEnumerable<VideoFile>> GetFilesBySeason(int seasonId, bool isRandom, int count, int startId)
        {
            if (isRandom)
                return await SearchRandom(b => b.SeasonId == seasonId, count);
            else
                return await Search(file => file.SeasonId == seasonId && file.Id > startId);
        }

        public async Task<IEnumerable<VideoFile>> GetFilesBySeriesAsync(int seriesId, bool isRandom, int startId)
        {
            if(isRandom)
                return await SearchRandom(b => b.SeriesId == seriesId);
            else
                return await Search(file => file.SeriesId == seriesId && file.Id > startId);
        }

        public async Task<VideoFile> GetRandomFileBySeriesId(int seriesId)
        {
            var result = await SearchRandom(b => b.SeriesId == seriesId, 1);

            return result.FirstOrDefault();
        }

        public async Task<IEnumerable<VideoFile>> SearchByName(string searchedValue)
        {
            var files =  Db.VideoFiles.Where(x => 
                EF.Functions.Like(x.Name, $"%{searchedValue.ToLower()}%") || EF.Functions.Like(x.VideoFileExtendedInfo.Director, $"%{searchedValue.ToLower()}%") ).Include(x => x.VideoFileExtendedInfo).Include(x =>x.VideoFileUserInfos);

            return files;

            //_FileRepository.SearchRandom
        }

        public async Task<IEnumerable<VideoFile>> SearchFileByType(VideoType type)
        {
            return Db.VideoFiles.Where(x => x.Type == type).Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).OrderBy(x => Guid.NewGuid());
        }

        public async Task<IEnumerable<VideoFile>> SearchFileWithSerieAsync(string searchedValue, bool isRandom, int resultCount)
        {
            var series = Db.Series.FirstOrDefault(x => EF.Functions.Like(x.Name, $"%{searchedValue.ToLower()}%"));

            var result = new List<VideoFile>();
            if (series == null)
                return result;

            var files = (Db.VideoFiles.Where(f => f.SeriesId == series.Id).ToList());

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
    }
}