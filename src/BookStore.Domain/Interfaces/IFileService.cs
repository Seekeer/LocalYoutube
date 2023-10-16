using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using FileStore.Domain.Models;

namespace FileStore.Domain.Interfaces
{
    public interface IDbFileService : IFileService<DbFile, VideoType>
    {
    }
    public interface IVideoFileService : IFileService<VideoFile, VideoType> { }
    public interface IAudioFileService : IFileService<AudioFile, AudioType> { }

    public interface IFileService<T,V> : IDisposable
        where T : DbFile
    {
        Task<IEnumerable<T>> GetAll();
        Task<T> GetById(int id);
        Task<T> Add(T File);
        Task<T> Update(T File);
        Task<bool> Remove(T File);
        Task<bool> Remove(int fileId);
        Task<IEnumerable<T>> GetFilesBySearies(int seriesId, bool isRandom, int startId);
        Task<IEnumerable<T>> GetFilesBySeason(int seriesId, bool isRandom, int count, int startId);
        Task<IEnumerable<T>> Search(string FileName);
        Task<IEnumerable<T>> SearchFileByType(V type);
        Task<IEnumerable<T>> SearchFileWithSeries(string searchedValue, bool isRandom);
        Task<T> GetRandomFileBySeriesId(int seriesId);
        Task SetRating(int videoId, double value);
        Task SetPosition(int videoId, string userId, double? value);
        Task<IEnumerable<T>> GetLatest(string userId);
    }
}