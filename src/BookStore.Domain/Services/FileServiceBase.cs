using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;

namespace FileStore.Domain.Services
{
    public class VideoFileService : FileServiceBase<VideoFile, VideoType>, IVideoFileService
    {
        public VideoFileService(IVideoFileRepository FileRepository) : base(FileRepository)
        {
        }
    }
    public class AudioFileService : FileServiceBase<AudioFile, AudioType>, IAudioFileService
    {
        public AudioFileService(IAudioFileRepository FileRepository) : base(FileRepository)
        {
        }
    }

    public class FileServiceBase<T,V> : IFileService<T,V>
        where T : DbFile
    {
        private readonly IFileRepository<T, V> _FileRepository;

        public FileServiceBase(IFileRepository<T, V> FileRepository)
        {
            _FileRepository = FileRepository;
        }

        public async Task<IEnumerable<T>> GetAll()
        {
            return await _FileRepository.GetAll();
        }

        public async Task<T> GetById(int id)
        {
            return await _FileRepository.GetById(id);
        }

        public async Task<T> Add(T File)
        {
            if (_FileRepository.SearchRandom(b => b.Name == File.Name).Result.Any())
                return null;

            await _FileRepository.Add(File);
            return File;
        }

        public async Task<T> Update(T File)
        {
            if (_FileRepository.SearchRandom(b => b.Name == File.Name && b.Id != File.Id).Result.Any())
                return null;

            await _FileRepository.Update(File);
            return File;
        }

        public async Task<bool> Remove(T File)
        {
            await _FileRepository.Remove(File);
            return true;
        }

        public async Task<IEnumerable<T>> GetFilesBySearies(int SeriesId, bool isRandom, int startId)
        {
            return await _FileRepository.GetFilesBySeriesAsync(SeriesId, isRandom, startId);
        }

        public async Task<IEnumerable<T>> GetFilesBySeason(int seasonId, bool isRandom, int count, int startId)
        {
            return await _FileRepository.GetFilesBySeason(seasonId, isRandom,  count,  startId);
        }

        public async Task<IEnumerable<T>> Search(string FileName)
        {
            return await _FileRepository.SearchByName((FileName));
        }

        public async Task<IEnumerable<T>> SearchFileWithSeries(string searchedValue, bool isRandom)
        {
            return await _FileRepository.SearchFileWithSerieAsync(searchedValue, isRandom);
        }

        public void Dispose()
        {
            _FileRepository?.Dispose();
        }

        public async Task<T> GetRandomFileBySeriesId(int seriesId)
        {
            return await _FileRepository.GetRandomFileBySeriesId(seriesId);
        }

        public async Task SetRating(int videoId, double value)
        {
            //var video = await _FileRepository.GetById(videoId);

            //video.TUserInfos.Rating = value;
            //await _FileRepository.Update(video);
        }

        public async Task SetPosition(int videoId, string userId, double? position)
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
            if(position != null)
                info.Position = position.Value;
            info.UpdatedDate = System.DateTime.Now;

            await _FileRepository.Update(video);
        }

        public async Task<IEnumerable<T>> SearchFileByType(V type)
        {
            return await _FileRepository.SearchFileByType(type);
        }

        public async Task<IEnumerable<T>> GetLatest(string userId)
        {
            return await _FileRepository.GetLatest(userId);
        }

    }
}