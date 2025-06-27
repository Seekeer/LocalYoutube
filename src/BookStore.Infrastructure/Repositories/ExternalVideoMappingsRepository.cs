using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Infrastructure;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace FileStore.Infrastructure.Repositories
{
    public interface IExternalVideoMappingsRepository : IRepository<ExternalVideoSourceMapping>
    {
        ExternalVideoSourceMapping GetExternalVideo(string channelId, string playlistId);
    }

    public class ExternalVideoMappingsRepository : Repository<ExternalVideoSourceMapping>, IExternalVideoMappingsRepository
    {
        public ExternalVideoMappingsRepository(VideoCatalogDbContext context) : base(context) { }

        public ExternalVideoSourceMapping GetExternalVideo(string channelId, string playlistId)
        {
            var channelsInfo = DbSet.Where(x => x.Network == DownloadType.Youtube && x.ChannelId == channelId);

            ExternalVideoSourceMapping result = null;
            if (string.IsNullOrEmpty(playlistId))
                result = channelsInfo.FirstOrDefault(x => x.Network == DownloadType.Youtube && x.ChannelId == channelId);

            if (result == null)
                result = channelsInfo.FirstOrDefault(x => x.PlaylistId == null);

            return result;
        }
    }

    public record ChannelInfo
    {
        public string ChannelId { get; set; }
        public string SeasonName { get; set; }
        public string SeriesName { get; set; }
        public bool FullDownload { get; set; }
    }

    public interface IExternalVideoMappingsService : IDisposable
    {
        Task CreateChannelMapping(DownloadType type, ChannelInfo info);
        Task<int> DownloadFinishedAsync(DbFile file, bool isVideoPropertiesFilled);
        Task AddExternalSourceMapping(IEnumerable<ChannelInfo> enumerable, DownloadType youtube);
        public Task<bool> FillFileFromSiteDownloadTask(string url, DbFile file, ChannelInfo channelInfo, DownloadType downloadType, int numberInSeries);
    }

    public class ExternalVideoMappingsService : IExternalVideoMappingsService
    {
        private readonly IExternalVideoMappingsRepository _externalVideoRepository;
        private readonly ISeriesRepository _seriesRepository;
        private readonly IDbFileService _dbFileService;

        public ExternalVideoMappingsService(IExternalVideoMappingsRepository externalVideoRepository, ISeriesRepository seriesRepository, IDbFileService dbFileService)
        {
            _externalVideoRepository = externalVideoRepository;
            _seriesRepository = seriesRepository;
            _dbFileService = dbFileService;
        }

        public void Dispose()
        {
            _externalVideoRepository?.Dispose();
        }

        public async Task AddExternalSourceMapping(IEnumerable<ChannelInfo> channelInfos, DownloadType type)
        {
            var externalSources = await _externalVideoRepository.SearchAsync(x => x.Network == type);

            foreach (var info in channelInfos.Where(x => !externalSources.Any(existing => existing.ChannelId == x.ChannelId)))
            {
                await CreateChannelMapping(type, info);
            }
        }

        public async Task CreateChannelMapping(DownloadType type, ChannelInfo info)
        {
            var series = _seriesRepository.AddOrUpdateSeries(type.ToString(), VideoType.ExternalVideo, null);
            var season = _seriesRepository.AddOrUpdateSeason(series, info.SeasonName);

            await _externalVideoRepository.AddAsync(new ExternalVideoSourceMapping
            {
                SeriesId = series.Id,
                SeasonId = season.Id,
                ChannelName = info.SeasonName,
                ChannelId = info.ChannelId,
                Network = type,
            });
        }

        public async Task<bool> FillFileFromSiteDownloadTask(string url, DbFile file, ChannelInfo channelInfo, DownloadType downloadType, int numberInSeries)
        {
            if (await _dbFileService.IsExternalDuplicate(url))
                return false;

            ExternalVideoSourceMapping channelMapping = null;
            bool createChannelMapping = false;
            if (channelInfo.ChannelId != null)
            {
                // Use Mapping
                channelMapping = await _externalVideoRepository.FindByQueryAsync(x => x.Network == downloadType && x.ChannelId == channelInfo.ChannelId && x.PlaylistId == null);
                if (channelMapping == null)
                {
                    createChannelMapping = true;
                }
            }

            if (channelMapping == null)
            {
                var series = (await _seriesRepository.SearchAsync(x => x.Name == channelInfo.SeriesName)).FirstOrDefault();
                if (series == null)
                {
                    series = _seriesRepository.AddOrUpdateSeries(channelInfo.SeriesName, (file as VideoFile)?.Type, (file as AudioFile).Type);
                }
                var season = _seriesRepository.AddOrUpdateSeason(series, channelInfo.SeasonName);
                channelMapping = new ExternalVideoSourceMapping
                {
                    SeriesId = series.Id,
                    ChannelName = channelInfo.SeasonName,
                    ChannelId = channelInfo.ChannelId,
                    SeasonId = season.Id,
                    Network = downloadType,
                };
                file.Season = season;
                file.Series = series;
            }

            if (createChannelMapping)
            {
                if (channelInfo.FullDownload)
                    channelMapping.LastCheckDate = new DateTime(2000, 1, 1);

                channelMapping.CheckNewVideo = true;
                await _externalVideoRepository.AddAsync(channelMapping);
            }

            FillFileFromSiteDownloadTask(file, numberInSeries, channelMapping);

            return true;
        }

        private static void FillFileFromSiteDownloadTask(DbFile file, int numberInSeries, ExternalVideoSourceMapping channelInfo)
        {
            file.SeasonId = channelInfo.SeasonId;
            file.SeriesId = channelInfo.SeriesId;

            file.IsDownloading = true;
            file.Number = numberInSeries;
        }

        public async Task<int> DownloadFinishedAsync(DbFile file, bool isVideoPropertiesFilled)
        {
            if (!isVideoPropertiesFilled || file.Duration == TimeSpan.Zero)
                VideoHelper.FillVideoProperties(file as VideoFile);

            file.IsDownloading = false;
            file.Name = file.Name.ClearFileName();

            await _dbFileService.AddAsync(file);

            return file.Id;
        }
    }

}