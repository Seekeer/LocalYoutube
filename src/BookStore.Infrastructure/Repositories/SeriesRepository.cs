using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace FileStore.Infrastructure.Repositories
{
    public class SeriesRepository : Repository<Series>, ISeriesRepository
    {
        public SeriesRepository(VideoCatalogDbContext context) : base(context) { }

        public async Task<IEnumerable<VideoFile>> SearchFileWithSeries(string searchedValue, int resultCount)
        {
            return await Random(Db.VideoFiles.AsNoTracking()
                    .Include(b => b.Season)
                    .Include(b => b.Series)
                    .Where(b => b.Name.Contains(searchedValue) ||
                                b.Series.Name.Contains(searchedValue)), resultCount)
                .ToListAsync();
        }

        public async Task<List<Series>> GetAll(VideoType? type)
        {
            if (type == null)
                return await DbSet.Include(x => x.Seasons).Where(x => x.Type != null).ToListAsync();

            var series =  DbSet.Include(x => x.Seasons).Where(x => x.Type == type);

            return await series.ToListAsync();
        }

        public async Task<IEnumerable<Series>> GetAll(AudioType? type)
        {
            if (type == null)
                return await DbSet.Include(x => x.Seasons).Where(x => x.AudioType != null).ToListAsync();

            var series = DbSet.Include(x => x.Seasons).Where(x => x.AudioType == type);
            return await series.ToListAsync();
        }
    }
}