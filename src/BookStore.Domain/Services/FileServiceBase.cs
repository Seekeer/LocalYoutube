using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;

namespace FileStore.Domain.Services
{
    public class DbFileService : FileServiceBase<DbFile, VideoType>, IDbFileService
    {
        public DbFileService(IDbFileRepository FileRepository) : base(FileRepository)
        {
        }

        public async Task<bool> IsExternalDuplicate(string externalLink)
        {
            var file = await _FileRepository.SearchRandom(x => x.VideoFileExtendedInfo.ExternalLink == externalLink);
            return file?.Any() == true;
        }
    }

    public class VideoFileService : FileServiceBase<VideoFile, VideoType>, IVideoFileService
    {
        private readonly ISeriesRepository _seriesRepository;

        public VideoFileService(IVideoFileRepository FileRepository, ISeriesRepository seriesRepository) : base(FileRepository)
        {
            _seriesRepository = seriesRepository;
        }


        public async Task MoveToAnotherSeriesByNameAsync(int fileId, string seriesName, bool moveWholeSeason)
        {
            var series = _seriesRepository.AddOrUpdateSeries(seriesName, VideoType.ExternalVideo, null);
            var file = await _FileRepository.GetById(fileId);

            if (file.SeriesId == series.Id)
                return;

            if (!moveWholeSeason)
            {
                var season = _seriesRepository.AddOrUpdateSeason(series, $"{file.Series.Name}_{file.Season.Name}");

                file.Series = series;
                file.Season = season;

                await _FileRepository.UpdateAsync(file);
            }
            else
            {
                await _seriesRepository.MoveSeasonToSeriesAsync(fileId, series.Id);
            }
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
        protected readonly IFileRepository<T, V> _FileRepository;

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

        public async Task<T> AddAsync(T File)
        {
            if (await _FileRepository.Any(b => b.Name == File.Name))
                return null;

            var season = File.Season;
            var series = File.Series;
            File.Season = null;
            File.Series = null;
            await _FileRepository.AddAsync(File);
            File.Series = series;
            File.Season = season;
            return File;
        }

        public async Task<T> Update(T File)
        {
            if (_FileRepository.SearchRandom(b => b.Name == File.Name && b.Id != File.Id).Result.Any())
                return null;

            await _FileRepository.UpdateAsync(File);
            return File;
        }

        public async Task<bool> Remove( T file)
        {
            if (file == null)
                return true;

            if (System.IO.File.Exists(file.Path))
            {
                try
                {
                    System.IO.File.Delete(file.Path);
                }
                catch (Exception ex)
                {
                    _FileRepository.MarkFileToDelete(file);

                    return false;
                }
            }

            _FileRepository.RemoveFileCompletely(file.Id);

            return true;
        }

        public async Task<bool> Remove(int fileId)
        {
            var file = await _FileRepository.GetById(fileId);
            return await Remove(file);
        }

        public async Task<IEnumerable<T>> GetFilesBySearies(int SeriesId, int count, bool isRandom, int startId)
        {
            return await _FileRepository.GetFilesBySeriesAsync(SeriesId, count, isRandom, startId);
        }

        public async Task<IEnumerable<T>> GetFilesBySeason(int seasonId, bool isRandom, int count, int startId)
        {
            return await _FileRepository.GetFilesBySeason(seasonId, isRandom,  count,  startId);
        }

        public async Task<IEnumerable<T>> Search(string FileName)
        {
            return await _FileRepository.SearchByName((FileName));
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

        public async Task<bool> SetPosition(int videoId, string userId, double? position, DateTime? updateTime)
        {
            if (string.IsNullOrEmpty(userId))
                return false;

            var video = await _FileRepository.GetById(videoId);

            if (video == null)
                return false;

            var info = video.VideoFileUserInfos.FirstOrDefault(x => x.UserId == userId);
            if (info == null)
            {
                info = new FileUserInfo { DbFile = video, UserId = userId };
                video.VideoFileUserInfos.Add(info);
            }
            else if (updateTime != null)
            {
                if(updateTime < info.UpdatedDate)
                    return false;
                else
                    info.UpdatedDate = updateTime.Value;
            }
            else
                info.UpdatedDate = System.DateTime.UtcNow;

            if (position != null)
                info.Position = position.Value;

            await _FileRepository.UpdateAsync(video);
            
            return true;
        }

        public async Task<FileUserInfo> GetPosition(int fileId, string userId)
        {
            if (string.IsNullOrEmpty(userId))
                return new FileUserInfo { };

            var video = await _FileRepository.GetById(fileId);
            var info = video.VideoFileUserInfos.FirstOrDefault(x => x.UserId == userId);
            if (info == null)
                return new FileUserInfo { };

            return info;
        }

        public async Task<IEnumerable<T>> SearchFileByType(V type)
        {
            return await _FileRepository.SearchFileByType(type);
        }

        public async Task<IEnumerable<T>> GetLatest(string userId, int count)
        {
            return await _FileRepository.GetLatest(userId, count);
        }

        public async Task<bool> MoveToSerie(int fileId, int serieId)
        {
            return await _FileRepository.MoveToSerie(fileId,  serieId);
        }

        public async Task<bool> MoveToSeason(int fileId, int seasonId)
        {
            return await _FileRepository.MoveToSeason(fileId, seasonId);
        }

        public async Task<IEnumerable<T>> GetNew(int count)
        {
            return await _FileRepository.GetNew(count);
        }
    }
}