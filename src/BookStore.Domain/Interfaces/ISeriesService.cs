using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using FileStore.Domain.Models;

namespace FileStore.Domain.Interfaces
{
    public interface ISeriesService : IDisposable
    {
        Task<IEnumerable<Series>> GetAllByType(VideoType? type, Origin? origin);
        Task<IEnumerable<Series>> GetAllByType(AudioType? type);
        Task<Series> GetById(int id);
        Task<Series> Add(Series Series);
        Task<Series> Update(Series Series);
        Task<bool> Remove(Series Series);
        Task<IEnumerable<Series>> Search(string SeriesName, int resultCount);
        Task MoveSeasonToFavorite(int seasonId, bool favorite);
        Task<bool> RemoveSeasonById(int id);
    }
}