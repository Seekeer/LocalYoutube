using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;

namespace FileStore.Domain.Services
{
    public class SeriesService : ISeriesService
    {
        private readonly ISeriesRepository _seriesRepository;
        private readonly IVideoFileService _fileService;

        public SeriesService(ISeriesRepository SeriesRepository, IVideoFileService fileService)
        {
            _seriesRepository = SeriesRepository;
            _fileService = fileService;
        }

        public async Task<IEnumerable<Series>> GetAllByType(VideoType? type, Origin? origin)
        {
            return await _seriesRepository.GetAll(type, origin);
            //var allTypes = await _seriesRepository.GetAll();

            //if (type == null)
            //    return allTypes;
            //else
            //    return allTypes.Where(x => x.Type == type);
        }

        public async Task<IEnumerable<Series>> GetAllByType(AudioType? type)
        {
            return await _seriesRepository.GetAll(type);
        }

        public async Task<Series> GetById(int id)
        {
            return await _seriesRepository.GetById(id);
        }

        public async Task<Series> Add(Series Series)
        {
            if (_seriesRepository.SearchRandom(c => c.Name == Series.Name).Result.Any())
                return null;

            await _seriesRepository.Add(Series);
            return Series;
        }

        public async Task<Series> Update(Series Series)
        {
            if (_seriesRepository.SearchRandom(c => c.Name == Series.Name && c.Id != Series.Id).Result.Any())
                return null;

            await _seriesRepository.Update(Series);
            return Series;
        }

        public async Task<bool> Remove(Series series)
        {
            var files = await _fileService.GetFilesBySearies(series.Id, 1000, true, 0);
            if (files.Any()) 
                return false;

            await _seriesRepository.Remove(series);
            return true;
        }

        public async Task<IEnumerable<Series>> Search(string SeriesName, int resultCount)
        {
            return await _seriesRepository.SearchRandom(c => c.Name.Contains(SeriesName), resultCount);
        }

        public void Dispose()
        {
            _seriesRepository?.Dispose();
        }

        public async Task MoveSeasonToFavorite(int seasonId, bool favorite)
        {
            await _seriesRepository.MoveSeasonToFavorite(seasonId, favorite);
        }

        public async Task<bool> RemoveSeasonById(int id)
        {
            return await _seriesRepository.RemoveSeasonById(id);
        }

    }
}