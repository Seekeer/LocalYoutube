using System;
using System.Collections.Generic;
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
            return await Db.Files.AsNoTracking().Include(b => b.Season).Include(b => b.Series)
                .OrderBy(b => b.Name)
                .ToListAsync();
        }

        public override async Task<VideoFile> GetById(int id)
        {
            var info = await Db.Files.AsNoTracking().Include(b => b.Season).Include(b => b.Series)
                .Include(file => file.VideoFileUserInfo).Include(file => file.VideoFileUserInfo)
                .Where(b => b.Id == id)
                .FirstOrDefaultAsync();

            

            return info;
        }

        public async Task<IEnumerable<VideoFile>> GetFilesBySeriesAsync(int seriesId)
        {
            return await Search(b => b.SeriesId == seriesId);
        }

        public async Task<VideoFile> GetRandomFileBySeriesId(int seriesId)
        {
            var result = await Search(b => b.SeriesId == seriesId, 1);

            return result.FirstOrDefault();
        }

        public async Task<IEnumerable<VideoFile>> SearchFileWithSeasonAsync(string searchedValue, int resultCount)
        {
            var series = Db.Series.FirstOrDefault(x => EF.Functions.Like(x.Name, $"%{searchedValue.ToLower()}%"));

            if (series == null)
                return new List<VideoFile>();

            var rand = new Random();
            var files = (Db.Files.Where(f => f.SeriesId == series.Id).ToList());
            var result = files.OrderBy(x => Guid.NewGuid()).Take(resultCount).ToList();
            result.ToList().ForEach(
                x =>
                {
                    Db.Entry(x).Reference(x => x.VideoFileExtendedInfo).Load();
                    Db.Entry(x).Reference(x => x.VideoFileUserInfo).Load();
                    x.SeriesId = series.Id;
                });

            return result;

        }
    }
}