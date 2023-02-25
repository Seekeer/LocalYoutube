using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using FileStore.Domain.Models;

namespace FileStore.Domain.Interfaces
{
    public interface IFileService : IDisposable
    {
        Task<IEnumerable<VideoFile>> GetAll();
        Task<VideoFile> GetById(int id);
        Task<VideoFile> Add(VideoFile File);
        Task<VideoFile> Update(VideoFile File);
        Task<bool> Remove(VideoFile File);
        Task<IEnumerable<VideoFile>> GetFilesBySearies(int seriesId, bool isRandom, int startId);
        Task<IEnumerable<VideoFile>> GetFilesBySeason(int seriesId, bool isRandom, int count, int startId);
        Task<IEnumerable<VideoFile>> Search(string FileName);
        Task<IEnumerable<VideoFile>> SearchFileByType(VideoType type);
        Task<IEnumerable<VideoFile>> SearchFileWithSeries(string searchedValue, bool isRandom);
        Task<VideoFile> GetRandomFileBySeriesId(int seriesId);
        Task SetRating(int videoId, double value);
        Task SetPosition(int videoId, double value, string userId);
    }
}