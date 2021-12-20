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
            return await Db.Files.AsNoTracking().Include(b => b.Season).Include(b => b.Series)
                .Where(b => b.Id == id)
                .FirstOrDefaultAsync();
        }

        public async Task<IEnumerable<VideoFile>> GetFilesBySeriesAsync(int seriesId)
        {
            return await Search(b => b.SeriesId == seriesId);
        }

        public async Task<IEnumerable<VideoFile>> SearchFileWithSeasonAsync(string searchedValue, int resultCount)
        {
            var series = Db.Series.FirstOrDefault(x => EF.Functions.Like(x.Name, $"%{searchedValue.ToLower()}%"));
            //var series = Db.Series.FirstOrDefault(x => x.Id == 1);

            if (series == null)
                return new List<VideoFile>();

            var rand = new Random();
            var files = (Db.Files.Where(f => f.SeriesId == series.Id).ToList());
            var result = files.OrderBy(x => Guid.NewGuid()).Take(5).ToList();
            result.Add(Db.Files.FirstOrDefault(x => x.Id == 1));
            result.ToList().ForEach(
            x => Db.Entry(x).Reference(x => x.VideoFileExtendedInfo).Load());
            //foreach (var item in result)
            //{
            //    item.VideoFileExtendedInfo = Db.FilesInfo.FirstOrDefault(info => info.VideoFileId == item.Id);
            //}

            var info = Db.FilesInfo.FirstOrDefault(info => info.VideoFileId == 41);
            return result;

            //return await Random(Db.Files.AsNoTracking()
            //        .Where(f => f.SeriesId == series.Id), resultCount)
            //    .ToListAsync();

            //return await Random(Db.Files.AsNoTracking()
            //        .Include(b => b.Season)
            //        .Include(b => b.Series)
            //        .Where(b => b.Name.Contains(searchedValue) ||
            //                    b.Series.Name.Contains(searchedValue)), resultCount)
            //    .ToListAsync();
        }
    }
}