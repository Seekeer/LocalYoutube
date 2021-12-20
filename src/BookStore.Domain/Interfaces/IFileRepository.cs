using System.Collections.Generic;
using System.Threading.Tasks;
using FileStore.Domain.Models;

namespace FileStore.Domain.Interfaces
{
    public interface IFileRepository : IRepository<VideoFile>
    {
        new Task<List<VideoFile>> GetAll();
        new Task<VideoFile> GetById(int id);
        Task<IEnumerable<VideoFile>> GetFilesBySeriesAsync(int seriesId);
        Task<IEnumerable<VideoFile>> SearchFileWithSeasonAsync(string searchedValue, int resultCount =10);
    }
}