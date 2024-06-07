using FileStore.Domain.Models;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace FileStore.Domain.Interfaces
{
    public interface ISeriesRepository : IRepository<Series>
    {
        Task<IEnumerable<VideoFile>> SearchFileWithSeries(string searchedValue, int resultCount);
        Task<List<Series>> GetAll(VideoType? type, Origin? origin);
        Task<IEnumerable<Series>> GetAll(AudioType? type);
        Task MoveSeasonToFavorite(int seasonId, bool favorite);
        Task<bool> RemoveSeasonById(int id);
        Task MoveSeasonToSeriesAsync(int fileId, int seriesId);
        Series AddOrUpdateSeries(string name, VideoType? type, AudioType? audioType);
        Season AddOrUpdateSeason(Series series, string name, bool doNotIgnoreSeriesId = true, bool isOrderMatter = false);
    }
}