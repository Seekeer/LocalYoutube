using API.FilmDownload;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using Microsoft.Extensions.DependencyInjection;
using QBittorrent.Client;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using System;
using Telegram.Bot.Types;
using TL;
using API.Controllers;
using Infrastructure;
using System.Diagnostics;
using System.Linq;
using Telegram.Bot.Types.ReplyMarkups;
using FileStore.Domain;
using Telegram.Bot;
using FileStore.Infrastructure.Context;

namespace API.TG
{
    public class FillVideoFileByTorrent : FillFileByTorrentBase
    {
        private readonly VideoType _type;

        public FillVideoFileByTorrent(RuTrackerUpdater _rutracker, AppConfig _config, TelegramBotClient _botClient,
            IServiceScopeFactory _serviceScopeFactory, TgBot _tgBot, VideoType type) : base(_rutracker, _config, _botClient, _serviceScopeFactory, _tgBot)
        {
            _type = type;
        }

        protected override async Task<DbFile> CreateAndFillFile(int rutrackerId, long tgFromId, IReadOnlyList<TorrentContent> torrentFiles, string downloadPath)
        {
            var videoFile = new FileStore.Domain.Models.VideoFile { SeriesId = 18, SeasonId = 91, };

            var info = await _rutracker.FillVideoInfo(rutrackerId);
            FillData(rutrackerId, info, downloadPath, videoFile);

            try
            {
                _rutracker.FillFileInfo(videoFile, info);
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }

            FillVideoSeriesSeasonType(tgFromId, _type, info, videoFile);

            await AnalyzeTorrentData(videoFile, tgFromId, _type, torrentFiles);
            await _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<IVideoFileRepository>().Add(videoFile);

            return videoFile;
        }

        protected async Task AnalyzeTorrentData(VideoFile file, long tgFromId, VideoType type, IReadOnlyList<TorrentContent> torrentFiles)
        {
            if (torrentFiles == null)
                return;

            var videos = torrentFiles;
            if ((type == VideoType.Film || type == VideoType.Animation) && videos.Count() > 1)
            {
                file.DoNotAutoFinish = true;
                await _botClient.SendTextMessageAsync(tgFromId, $"⚠️ В раздаче {file.Name} {videos.Count()} много файлов. Возможны проблемы, проверьте.");
            }

            // Direct path to biggest file so it can be watched during downloading. 
            file.Path = Path.Combine(file.Path, videos.OrderByDescending(x => x.Size).First().Name + ".!qB");
        }

        protected void FillVideoSeriesSeasonType(long tgFromId, VideoType type, RutrackerInfo info, VideoFile file)
        {
            var db = _serviceScopeFactory.CreateDb();
            var manager = new DbUpdateManager(db);

            var tgRecord = _tgBot.GetDict().FirstOrDefault(x => x.TgId == tgFromId);
            if (type == VideoType.AdultEpisode)
            {
                var series = manager.AddOrUpdateVideoSeries(info.Name, false, VideoType.AdultEpisode);
                file.SeriesId = series.Id;
                // TODO hardcode
                file.SeasonId = 91;
            }
            else if (type == VideoType.ChildEpisode)
            {
                var series = manager.AddOrUpdateVideoSeries(info.Name, false, VideoType.ChildEpisode);
                file.SeriesId = series.Id;
                // TODO hardcode
                file.SeasonId = 91;
            }
            else if (type == VideoType.Film && tgRecord != null)
            {
                file.SeasonId = tgRecord.FilmSeasonId;
            }
            else if (type == VideoType.Animation && tgRecord != null)
            {
                var series = manager.AddOrUpdateVideoSeries("Полнометражные мультики скаченные", false, VideoType.Animation);
                file.SeriesId = series.Id;
                var childDownloaded = manager.AddOrUpdateSeason(series, "Детские мультики");
                file.SeasonId = childDownloaded.Id;
            }
            else if (type == VideoType.FairyTale && tgRecord != null)
            {
                // TODO hardcode
                file.SeriesId = 11;
                file.SeasonId = manager.AddOrUpdateSeason(11, "Сказки скаченные").Id;
            }
            else if (type == VideoType.Art && tgRecord != null)
            {
                // TODO hardcode
                file.SeriesId = 2038;
                file.SeasonId = manager.AddOrUpdateSeason(2038, file.Name).Id;
            }
            else
                Debug.Assert(false);

            file.Type = type;
        }
    }

    public class FillAudioFileByTorrent : FillFileByTorrentBase
    {
        private readonly AudioType _type;

        public FillAudioFileByTorrent(RuTrackerUpdater _rutracker, AppConfig _config, TelegramBotClient _botClient,
            IServiceScopeFactory _serviceScopeFactory, TgBot _tgBot, AudioType type) : base(_rutracker, _config, _botClient, _serviceScopeFactory, _tgBot)
        {
            _type = type;
        }

        protected override async Task<DbFile> CreateAndFillFile(int rutrackerId, long tgFromId, IReadOnlyList<TorrentContent> torrentFiles, string downloadPath)
        {
            var audioFile = new FileStore.Domain.Models.AudioFile {};

            var info = await _rutracker.FillAudioInfo(rutrackerId);
            FillData(rutrackerId, info, downloadPath, audioFile);
            audioFile.Name = info.BookTitle;

            try
            {
                _rutracker.FillFileInfo(audioFile, info);
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }

            FillAudioSeriesSeasonType(tgFromId, _type, info, audioFile);
            await _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<IAudioFileRepository>().Add(audioFile);

            return audioFile;
        }

        protected void FillAudioSeriesSeasonType(long tgFromId, AudioType audioType, AudioInfo info, AudioFile file)
        {
            var db = _serviceScopeFactory.CreateDb();
            var manager = new DbUpdateManager(db);

            file.Type = audioType;

            Series series = null;

            switch (audioType)
            {
                case AudioType.FairyTale:
                    series = manager.AddOrUpdateSeries("info.Director Аудиосказки", false, true);
                    break;
                case AudioType.AudioBook:
                    series = manager.AddOrUpdateSeries(info.Author ?? "Rutracker Аудиокниги", false, true);
                    break;
                default:
                    throw new ArgumentException(nameof(audioType));
            }

            series.AudioType = audioType;
            file.SeriesId = series.Id;

            var season1 = manager.AddOrUpdateSeason(series, info.BookTitle);
            file.SeasonId = season1.Id;
            db.SaveChanges();
        }
    }

    public abstract class FillFileByTorrentBase
        //<TorrentInfo, File>
        //where TorrentInfo: RutrackerInfo
        //where File: DbFile
    {
        protected readonly AppConfig _config;
        protected readonly TelegramBotClient _botClient;
        protected readonly RuTrackerUpdater _rutracker;
        protected readonly IServiceScopeFactory _serviceScopeFactory;
        protected readonly TgBot _tgBot;

        protected FillFileByTorrentBase(RuTrackerUpdater rutracker, AppConfig config, TelegramBotClient botClient,
            IServiceScopeFactory serviceScopeFactory, TgBot tgBot)
        {
            _config = config;
            _rutracker = rutracker;
            _botClient = botClient;
            _serviceScopeFactory = serviceScopeFactory;
            _tgBot = tgBot;
        }

        public async Task CreateDbFile(int rutrackerId, long tgFromId, SearchRecord record, string downloadPath = null)
        {
            IReadOnlyList<TorrentContent> torrentFiles = null;
            if (string.IsNullOrEmpty(downloadPath))
            {
                downloadPath = Path.Combine(_config.RootDownloadFolder, "Rutracker", rutrackerId.ToString());
                try
                {
                    torrentFiles = await _rutracker.StartDownload(rutrackerId, downloadPath);
                }
                catch (Exception ex)
                {
                    NLog.LogManager.GetCurrentClassLogger().Error(ex);
                    await _botClient.SendTextMessageAsync(new ChatId(tgFromId), $"Ошибка при добавлении торрента в QBittorrent. Попробуйте еще раз позже");
                    return;
                }
            }

            var file = await CreateAndFillFile(rutrackerId, tgFromId, torrentFiles, downloadPath);

            await _tgBot.ProcessTelegram(file, tgFromId, record);

            if (file.Cover == null || file.Cover?.Length < 20 * 1024)
                await _tgBot.SearchCoverForFile(file, tgFromId);
        }

        protected abstract Task<DbFile> CreateAndFillFile(int rutrackerId, long tgFromId, IReadOnlyList<TorrentContent> torrentFiles, string downloadPath);

        protected void FillData(int id, RutrackerInfo info, string downloadPath, DbFile file)
        {
            file.Name = _rutracker.ClearFromForeignOption(info.Name);
            file.IsDownloading = true;
            file.Path = downloadPath;
            file.VideoFileExtendedInfo.RutrackerId = id;
        }

    }
}
