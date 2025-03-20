using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using FileStore.Domain.Models;

namespace FileStore.Domain.Interfaces
{
    public interface IDbFileService : IFileService<DbFile, VideoType>
    {
        Task<bool> IsExternalDuplicate(string key);
    }
    public interface IVideoFileService : IFileService<VideoFile, VideoType> {
        Task MoveToAnotherSeriesByNameAsync(int fileId, string seriesName, bool moveWholeSeason);
    }
    public interface IAudioFileService : IFileService<AudioFile, AudioType> { }

    public interface IFileService<T,V> : IDisposable
        where T : DbFile
    {
        Task<IEnumerable<T>> GetAll();
        Task<T> GetById(int id);
        Task<T> AddAsync(T File);
        Task<T> Update(T File);
        Task<bool> Remove(T File);
        Task<bool> Remove(int fileId);
        Task<IEnumerable<T>> GetFilesBySearies(int seriesId, int count, bool isRandom, int startId);

        /// <summary>
        /// 
        /// </summary>
        /// <param name="seriesId"></param>
        /// <param name="isRandom"></param>
        /// <param name="count">Only in case of random</param>
        /// <param name="startId">Only in case of non-random</param>
        /// <returns></returns>
        Task<IEnumerable<T>> GetFilesBySeason(int seriesId, bool isRandom, int count, int startId);
        Task<IEnumerable<T>> Search(string FileName);
        Task<IEnumerable<T>> SearchFileByType(V type);
        Task<T> GetRandomFileBySeriesId(int seriesId);
        Task SetRating(int videoId, double value);
        Task<bool> SetPosition(int videoId, string userId, double? value, DateTime? updateTime);
        Task<IEnumerable<T>> GetLatest(string userId, int count);
        Task<bool> MoveToSerie(int fileId, int serieId);
        Task<bool> MoveToSeason(int fileId, int seasonId);
        Task<FileUserInfo> GetPosition(int fileId, string userId);
        Task<IEnumerable<T>> GetNew(int count, string userId);
        Task SkipNew(int id, string userId);
    }
}