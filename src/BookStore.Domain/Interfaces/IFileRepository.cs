using System.Collections.Generic;
using System.Threading.Tasks;
using FileStore.Domain.Models;

namespace FileStore.Domain.Interfaces
{
    public interface IDbFileRepository : IFileRepository<DbFile, VideoType> { }
    public interface IVideoFileRepository : IFileRepository<VideoFile, VideoType> { }
    public interface IAudioFileRepository : IFileRepository<AudioFile, AudioType> { }

    public interface IFileRepository<T,V> : IRepository<T>
        where T : DbFile
    {
        new Task<List<T>> GetAll();
        new Task<T> GetById(int id);
        Task<IEnumerable<T>> SearchFileByType(V type);
        Task<IEnumerable<T>> GetFilesBySeriesAsync(int seriesId, bool isRandom, int startId);
        Task<IEnumerable<T>> SearchFileWithSerieAsync(string searchedValue, bool isRandom, int resultCount =10);
        Task<T> GetRandomFileBySeriesId(int seriesId);
        Task<IEnumerable<T>> SearchByName(string fileName);
        Task<IEnumerable<T>> GetFilesBySeason(int seriesId, bool isRandom, int count, int startId);
        Task<IEnumerable<T>> GetLatest(string userId);
        void RemoveFileCompletely(T file);
        void MarkFileToDelete(T file);
    }
}