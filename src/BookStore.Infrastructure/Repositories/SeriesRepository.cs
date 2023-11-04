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
                    .Where(b => !b.Series.IsArchived && (b.Name.Contains(searchedValue) ||
                                b.Series.Name.Contains(searchedValue))), resultCount)
                .ToListAsync();
        }

        public async Task<List<Series>> GetAll(VideoType? type)
        {
            if (type == null)
                return await DbSet.Include(x => x.Seasons).Where(x => !x.IsArchived && x.Type != null).ToListAsync();

            var series =  DbSet.Include(x => x.Seasons).Where(x => !x.IsArchived && x.Type == type);

            return await series.ToListAsync();
        }

        public async Task<IEnumerable<Series>> GetAll(AudioType? type)
        {
            if (type == null)
                return await DbSet.Include(x => x.Seasons).Where(x => x.AudioType != null).ToListAsync();

            var series = DbSet.Include(x => x.Seasons).Where(x => x.AudioType == type);
            return await series.ToListAsync();
        }

        public async Task MoveSeasonToFavorite(int seasonId)
        {
            var season = Db.Seasons.FirstOrDefault(x => x.Id == seasonId);

            var series = DbSet.FirstOrDefault(x => x.Id == season.SeriesId);
            var typeStr = series.Type != null ? series.Type.ToString() : series.AudioType.ToString();
            var newSeries = AddOrUpdateSeries($"Избранное {typeStr}", series.Type, series.AudioType);

            season.SeriesId = newSeries.Id;
            foreach (var file in Db.Files.Where(x => x.SeasonId == seasonId))
            {
                file.SeriesId = newSeries.Id;
            }

            Db.SaveChanges();
        }

        public Series AddOrUpdateSeries(string name, VideoType? type, AudioType? audioType)
        {
            var series = DbSet.FirstOrDefault(x => x.Name == name);
            if (series == null)
            {
                series = new Series { Name = name };
                series.Type = type;
                series.AudioType = audioType;
                DbSet.Add(series);

                Db.SaveChanges();
            }

            return series;
        }
    }
}