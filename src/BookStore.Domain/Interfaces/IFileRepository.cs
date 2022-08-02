using System.Collections.Generic;
using System.Threading.Tasks;
using FileStore.Domain.Models;

namespace FileStore.Domain.Interfaces
{
    public interface IFileRepository : IRepository<VideoFile>
    {
        new Task<List<VideoFile>> GetAll();
        new Task<VideoFile> GetById(int id);
        Task<IEnumerable<VideoFile>> SearchFileByType(VideoType type);
        Task<IEnumerable<VideoFile>> GetFilesBySeriesAsync(int seriesId, bool isRandom);
        Task<IEnumerable<VideoFile>> SearchFileWithSeasonAsync(string searchedValue, bool isRandom, int resultCount =10);
        Task<VideoFile> GetRandomFileBySeriesId(int seriesId);
        Task<IEnumerable<VideoFile>> SearchByName(string fileName);
        Task<IEnumerable<VideoFile>> GetFilesBySeason(int seriesId, bool isRandom, int count);
    }
}