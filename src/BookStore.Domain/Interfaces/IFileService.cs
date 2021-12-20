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
        Task<IEnumerable<VideoFile>> GetFilesBySearies(int SeriesId);
        Task<IEnumerable<VideoFile>> Search(string FileName);
        Task<IEnumerable<VideoFile>> SearchFileWithSeries(string searchedValue);
    }
}