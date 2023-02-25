using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;

namespace FileStore.Domain.Services
{
    public class FileService : IFileService
    {
        private readonly IFileRepository _FileRepository;

        public FileService(IFileRepository FileRepository)
        {
            _FileRepository = FileRepository;
        }

        public async Task<IEnumerable<VideoFile>> GetAll()
        {
            return await _FileRepository.GetAll();
        }

        public async Task<VideoFile> GetById(int id)
        {
            return await _FileRepository.GetById(id);
        }

        public async Task<VideoFile> Add(VideoFile File)
        {
            if (_FileRepository.SearchRandom(b => b.Name == File.Name).Result.Any())
                return null;

            await _FileRepository.Add(File);
            return File;
        }

        public async Task<VideoFile> Update(VideoFile File)
        {
            if (_FileRepository.SearchRandom(b => b.Name == File.Name && b.Id != File.Id).Result.Any())
                return null;

            await _FileRepository.Update(File);
            return File;
        }

        public async Task<bool> Remove(VideoFile File)
        {
            await _FileRepository.Remove(File);
            return true;
        }

        public async Task<IEnumerable<VideoFile>> GetFilesBySearies(int SeriesId, bool isRandom, int startId)
        {
            return await _FileRepository.GetFilesBySeriesAsync(SeriesId, isRandom, startId);
        }

        public async Task<IEnumerable<VideoFile>> GetFilesBySeason(int seasonId, bool isRandom, int count, int startId)
        {
            return await _FileRepository.GetFilesBySeason(seasonId, isRandom,  count,  startId);
        }

        public async Task<IEnumerable<VideoFile>> Search(string FileName)
        {
            return await _FileRepository.SearchByName((FileName));
        }

        public async Task<IEnumerable<VideoFile>> SearchFileWithSeries(string searchedValue, bool isRandom)
        {
            return await _FileRepository.SearchFileWithSerieAsync(searchedValue, isRandom);
        }

        public void Dispose()
        {
            _FileRepository?.Dispose();
        }

        public async Task<VideoFile> GetRandomFileBySeriesId(int seriesId)
        {
            return await _FileRepository.GetRandomFileBySeriesId(seriesId);
        }

        public async Task SetRating(int videoId, double value)
        {
            //var video = await _FileRepository.GetById(videoId);

            //video.VideoFileUserInfos.Rating = value;
            //await _FileRepository.Update(video);
        }

        public async Task SetPosition(int videoId, double value, string userId)
        {
            if (string.IsNullOrEmpty(userId))
                return;

            var video = await _FileRepository.GetById(videoId);

            var info = video.VideoFileUserInfos.FirstOrDefault(x => x.UserId == userId);
            if (info == null)
            {
                info = new FileUserInfo { DbFile = video, UserId = userId};
                video.VideoFileUserInfos.Add(info);
            }
            info.Position = value;

            await _FileRepository.Update(video);
        }

        public async Task<IEnumerable<VideoFile>> SearchFileByType(VideoType type)
        {
            return await _FileRepository.SearchFileByType(type);
        }
    }
}