using Microsoft.EntityFrameworkCore;
using API.Controllers;
using FileStore.API;
using FileStore.Domain.Interfaces;
using Microsoft.Extensions.DependencyInjection;
using RuTracker.Client.Model.SearchTopics.Response;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Telegram.Bot;
using Telegram.Bot.Extensions.Polling;
using Telegram.Bot.Types;
using Telegram.Bot.Types.ReplyMarkups;
using Tg = Telegram.Bot.Types.Enums;
using Infrastructure;
using FileStore.Domain.Models;
using System.Drawing;
using API.TG;
using System.Diagnostics;
using static System.Net.WebRequestMethods;
using AngleSharp.Dom;
using System.Text;
using Polly;
using static System.Net.Mime.MediaTypeNames;
using FileStore.Domain;
using FileStore.Domain.Services;
//using Polly;

namespace API.FilmDownload
{
    public class SearchRecord
    {
        public SearchTopicInfo Topic { get; set; }
        public int MessageId { get; set; }
        public string SearchSctring { get; set; }
    }

    public class TgLink
    {
        public long TgId { get; set; }
        public int FilmSeasonId { get; set; }
    }

    public class TgBot
    {
        private readonly IServiceScopeFactory _serviceScopeFactory;
        private readonly AppConfig _config;
        private readonly TelegramBotClient _botClient;
        private readonly RuTrackerUpdater _rutracker;
        private readonly List<SearchRecord> _infos = new List<SearchRecord>();
        private readonly Dictionary<string, SearchResult> _images = new Dictionary<string, SearchResult>();
        private readonly List<TgLink> _tgSeasonDict = new List<TgLink>(); 
        public const string UPDATECOVER_MESSAGE = "Обновить обложку";
        public const string SETUP_VLC_Message = "Настроить VLC";
        public const string SHOW_ALL_SEARCH_RESULT_Message = "Показать все результаты поиска";
        private Timer _timer;

        public TgBot(AppConfig config, IServiceScopeFactory serviceScopeFactory)
        {
            _serviceScopeFactory = serviceScopeFactory;
            _config = config;
            _botClient = new TelegramBotClient(config.TelegramSettings.ApiKey);
            _rutracker = new RuTrackerUpdater(config);

            NLog.LogManager.GetCurrentClassLogger().Warn($"Telegram bot created");

            SendAdminMessage($"Сервер стартанул");

            CreateTGDict();
        }

        private void CreateTGDict()
        {
            var db = _GetDb();
            var manager = new DbUpdateManager(db);
            var seriesDownload = db.Series.First(x => x.Id == 18);

            // Helen
            _tgSeasonDict.Add(new TgLink { TgId = 360495063, FilmSeasonId = manager.AddOrUpdateSeason(seriesDownload, "Алена").Id});
            // DIMA
            _tgSeasonDict.Add(new TgLink { TgId = 176280269, FilmSeasonId = manager.AddOrUpdateSeason(seriesDownload, "Дима").Id });
            _tgSeasonDict.Add(new TgLink { TgId = 1618298918, FilmSeasonId = manager.AddOrUpdateSeason(seriesDownload, "Дима").Id });
            // Jully
            _tgSeasonDict.Add(new TgLink { TgId = 76951227, FilmSeasonId = manager.AddOrUpdateSeason(seriesDownload, "Юля").Id });
        }

        private async Task SendAdminMessage(string message)
        {
            await _botClient.SendTextMessageAsync(

                            chatId: _config.TelegramSettings.AdminId,
                            text: message,
                            disableWebPagePreview: true,
                            replyMarkup: GetKeyboard(true)
                        );
        }

        private ReplyKeyboardMarkup GetKeyboard(bool isAdmin = false)
        {
            ReplyKeyboardMarkup t = new ReplyKeyboardMarkup(GetKeyboardButtons(isAdmin));
            t.ResizeKeyboard = true;
            t.OneTimeKeyboard = true;
            return t;
        }

        private List<KeyboardButton> GetKeyboardButtons(bool isAdmin)
        {
            var keyboard = new List<KeyboardButton>();

            if (isAdmin)
            {
                keyboard.Add(new KeyboardButton(UPDATECOVER_MESSAGE));
                keyboard.Add(new KeyboardButton(SETUP_VLC_Message));
            }

            return keyboard;
        }
        public async Task Start()
        {
            using var cts = new System.Threading.CancellationTokenSource();
            // StartReceiving does not block the caller thread. Receiving is done on the ThreadPool.
            var receiverOptions = new ReceiverOptions
            {
                //AllowedUpdates = { UpdateType.Message } // receive all update types
                AllowedUpdates = {  } // receive all update types
            };

            _botClient.StartReceiving(
                this.HandleUpdateAsync,
                HandleErrorAsync,
                receiverOptions,
                cancellationToken: cts.Token);

            await _rutracker.Init();

            _timer = new Timer(TimerCallback, null, 0, (int)TimeSpan.FromMinutes(2).TotalMilliseconds);
        }

        private async Task ReAddExistingTopics()
        {
            var list = await _rutracker.Get();
            foreach (var item in list)
            {
                try
                {
                    var dir = new DirectoryInfo(item.SavePath);
                    var folder = dir.Name;
                    var id = int.Parse(folder);
                    await FillVideoFileId(id, 111, null, VideoType.Film, item.SavePath);
                }
                catch (Exception ex)
                {
                }
            }
        }

        private void TimerCallback(Object o)
        {
            // Discard the result
            lock (_botClient)
            {
                //_ = DoAsyncPing();
            }
        }

        private async Task DoAsyncPing()
        {
            var db = _GetDb();
            var manager = new DbUpdateManager(db);

            var updated = manager.UpdateDownloading((info) => info.IsDownloading);

            foreach (var item in updated)
            {
                var telegramId = _config.TelegramSettings.InfoGroupId;
                var telegramLink = _tgSeasonDict.FirstOrDefault(x => x.FilmSeasonId == item.SeriesId);
                if (telegramLink != null)
                    telegramId = telegramLink.TgId;

                await NotifyDownloadEnded(telegramId, item);
            }
        }

        private async Task NotifyDownloadEnded(long telegramId, VideoFile item)
        {
             await _botClient.SendTextMessageAsync(new ChatId(telegramId), $"Закончена закачка {item.Name} {Environment.NewLine} Открыть в VLC: http://192.168.1.55:2022/api/Files/getFileById?fileId={item.Id}");
        }

        private FileStore.Infrastructure.Context.VideoCatalogDbContext _GetDb()
        {
            return _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<FileStore.Infrastructure.Context.VideoCatalogDbContext>();
        }

        public async Task SearchCoverForFile(DbFile file, long tgAccountId)
        {
            var search = new SearchEngine("f228f7e30451842e8", "AIzaSyB9gRWRoQRXZiLcX7ZUACwi-Smm5L8R-Mg");
            var results = search.Search($"фильм {file.Name} {file.VideoFileExtendedInfo.Year}", file.Name);

            if (!results.Any())
                await _botClient.SendTextMessageAsync(tgAccountId, $"Ничего не найдено для фильма {file.Name} {file.Id}");

            foreach (var image in results)
            {
                try
                {
                    var keyboard = new List<InlineKeyboardButton>();
                    var guid = Guid.NewGuid().ToString();
                    keyboard.Add(new InlineKeyboardButton($"Использовать эту обложку") { CallbackData = CommandParser.GetMessageFromData(CommandType.FixCover, guid.ToString()) });
                    var tgMessage = await _botClient.SendPhotoAsync(new ChatId(tgAccountId),
                        new Telegram.Bot.Types.InputFiles.InputOnlineFile(image.Url),
                        caption: $"{file.Name} {file.VideoFileExtendedInfo.Year} высота {image.Bitmap.Height} px", replyMarkup: new InlineKeyboardMarkup(keyboard));

                    image.File = file;
                    image.TgMessageId = tgMessage.MessageId;
                    image.TgId = tgAccountId;
                    _images.Add(guid, image);
                }
                catch (Exception ex)
                {
                }
            }

        }

        private async Task UpdateFile(SearchResult data)
        {
            try
            {
                var fileRepo = _serviceScopeFactory.CreateScope().ServiceProvider.
                    GetRequiredService<IVideoFileRepository>();

                var file = await fileRepo.GetById(data.File.Id);

                ImageConverter converter = new ImageConverter();
                var bytes = (byte[])converter.ConvertTo(data.Bitmap, typeof(byte[]));

                file.VideoFileExtendedInfo.SetCover(bytes);
                await fileRepo.Update(file);

                var tgMessage = await _botClient.SendTextMessageAsync(new ChatId(data.TgId),
                    "Картинка обновлена", replyToMessageId: data.TgMessageId);

                foreach (var item in _images.Where(x => x.Value.File.Id == file.Id))
                {
                    if (item.Value.TgMessageId != data.TgMessageId)
                        await _botClient.DeleteMessageAsync(new ChatId(data.TgId), item.Value.TgMessageId);
                }
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }
        }

        private async Task AddTorrent(string data, long fromId, VideoType type, AudioType? audioType = null)
        {
            if (!int.TryParse(data, out var id))
                return;

            //await _botClient.SendTextMessageAsync(new ChatId(_config.TelegramSettings.ChatId), update.CallbackQuery.Data);
            var record = _infos.FirstOrDefault(x => x.Topic.Id == id);
            var searchInfo = record.Topic;

            NLog.LogManager.GetCurrentClassLogger().Info($"Got info for thread:{searchInfo.Id}|{searchInfo.Title}");
            await FillVideoFileId(id, fromId, record, type);
        }

        public static async Task HandleErrorAsync(ITelegramBotClient botClient, Exception exception, CancellationToken cancellationToken)
        {
            try
            {
                NLog.LogManager.GetCurrentClassLogger().Error(exception);
            }
            catch (Exception ex)
            {
            }
        }

        public async Task HandleUpdateAsync(ITelegramBotClient botClient, Update update, CancellationToken cancellationToken)
        {
            

            try
            {
                switch (update.Type)
                {
                    case Tg.UpdateType.Unknown:
                        break;
                    case Tg.UpdateType.Message:
                        if (_tgSeasonDict.Any(x => x.TgId == update.Message.From.Id))
                            await this._botClient_OnMessage(botClient, update.Message);
                        break;
                    case Tg.UpdateType.InlineQuery:
                        break;
                    case Tg.UpdateType.ChosenInlineResult:
                        break;
                    case Tg.UpdateType.CallbackQuery:
                        if (!_tgSeasonDict.Any(x => x.TgId == update.CallbackQuery.From.Id))
                            return;

                        var command = CommandParser.GetDataFromMessage(update.CallbackQuery.Data);

                        switch (command.Type)
                        {
                            case CommandType.FixCover:
                                await UpdateFile(_images[command.Data]);
                                break;
                            case CommandType.Series:
                                await AddTorrent(command.Data, update.CallbackQuery.From.Id, VideoType.AdultEpisode);
                                break;
                            case CommandType.Film:
                                await AddTorrent(command.Data, update.CallbackQuery.From.Id, VideoType.Film);
                                break;
                            case CommandType.ChildSeries:
                                await AddTorrent(command.Data, update.CallbackQuery.From.Id, VideoType.ChildEpisode);
                                break;
                            case CommandType.Animation:
                                await AddTorrent(command.Data, update.CallbackQuery.From.Id, VideoType.Animation);
                                break;
                            case CommandType.FairyTale:
                                await AddTorrent(command.Data, update.CallbackQuery.From.Id, VideoType.FairyTale);
                                break;
                            case CommandType.Art:
                                await AddTorrent(command.Data, update.CallbackQuery.From.Id, VideoType.Art);
                                break;
                            case CommandType.AudioFairyTale:
                                //await AddTorrent(command.Data, update.CallbackQuery.From.Id, VideoType.FairyTale);
                                break;
                            case CommandType.ShowAllSearchResult:
                                await ProcessUserInput(command.Data, update.CallbackQuery.From.Id, false);
                                break;
                            case CommandType.YoutubeAsDesigned:
                                await ProcessYoutubeVideo(command.Data, update.CallbackQuery.From.Id, update.CallbackQuery.Message, false);
                                break;
                            case CommandType.YoutubeWatchLater:
                                await ProcessYoutubeVideo(command.Data, update.CallbackQuery.From.Id, update.CallbackQuery.Message, true);
                                break;
                            case CommandType.Delete:
                                await DeleteFile(update.CallbackQuery.Id, command.Data);
                                break;
                            case CommandType.Unknown:
                                break;
                            default:
                                break;
                        }
                        break;
                    case Tg.UpdateType.EditedMessage:
                        break;
                    case Tg.UpdateType.ChannelPost:
                        break;
                    case Tg.UpdateType.EditedChannelPost:
                        break;
                    case Tg.UpdateType.ShippingQuery:
                        break;
                    case Tg.UpdateType.PreCheckoutQuery:
                        break;
                    case Tg.UpdateType.Poll:
                        break;
                    case Tg.UpdateType.PollAnswer:
                        break;
                    case Tg.UpdateType.MyChatMember:
                        break;
                    case Tg.UpdateType.ChatMember:
                        break;
                    case Tg.UpdateType.ChatJoinRequest:
                        break;
                    default:
                        break;
                }
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);

                var messageId = update.Message != null ? update.Message.MessageId : update.CallbackQuery.Message.MessageId;
                var userId = update.Message != null ? update.Message.From.Id : update.CallbackQuery.Message.From.Id;

                try
                {
                    await _botClient.SendTextMessageAsync(new ChatId(userId), $"Ошибка при обработке торрента",
                        null, null, null, null, null, messageId);
                }
                catch (Exception)
                {
                }
            }
        }

        private async Task SetupVLC(long id)
        {
            var message = @$"1. Положи файлы из bat.zip в C:\Program Files\VideoLAN\VLC 
2. Запусти vlc-protocol-register.bat";

            using (var stream = System.IO.File.OpenRead(@"Assets\bat.zip"))
            {
                var file = new Telegram.Bot.Types.InputFiles.InputOnlineFile(stream, "bat.zip");

                await _botClient.SendDocumentAsync(
                    caption: message,
                    chatId: id,
                    document: file
                );
            }
        }

        private async Task DeleteFile(string callbackId, string data)
        {
            try
            {
                await _rutracker.DeleteTorrent(data);

                var db = _GetDb();
                var id = int.Parse(data);
                var file = db.FilesInfo.FirstOrDefault(x => x.RutrackerId == id);
                if (file != null)
                { 
                    db.Entry(file).State = EntityState.Detached;
                    using var fileService = _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<IDbFileService> ();
                    await fileService.Remove(file.VideoFileId);
                }

                await _botClient.AnswerCallbackQueryAsync(callbackId, "Видео удалено");
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
                await _botClient.AnswerCallbackQueryAsync(callbackId, "Ошибка при удалении");
            }
        }

        private async Task FillVideoFileId(int rutrackerId, long tgFromId, SearchRecord record, 
            VideoType type, string downloadPath = null)
        {
            var info = await _rutracker.FillInfo(rutrackerId);

            if (string.IsNullOrEmpty(downloadPath))
            {
                downloadPath = Path.Combine(_config.RootDownloadFolder, rutrackerId.ToString());
                await _rutracker.StartDownload(rutrackerId, downloadPath);
            }

            var file = new FileStore.Domain.Models.VideoFile
            {
                SeriesId = 18,
                SeasonId = 91,
            };
            FillData(rutrackerId, info, downloadPath, file);

            FillFilePropertiesByType(tgFromId, type, info, file);

            await _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<IVideoFileRepository>().Add(file);

            await ProcessTelegram(file, tgFromId, info, record);

            if (file.Cover == null || file.Cover?.Length < 20 * 1024)
                await SearchCoverForFile(file, tgFromId);
        }

        private void FillFilePropertiesByType(long tgFromId, VideoType type, VideoInfo info, VideoFile file)
        {
            var db = _GetDb();
            var manager = new DbUpdateManager(db);

            var tgRecord = _tgSeasonDict.FirstOrDefault(x => x.TgId == tgFromId);
            var downloadSeries = manager.GetDownloadSeries();
            if (type == VideoType.AdultEpisode)
            {
                var series = manager.AddOrUpdateVideoSeries(info.Name, false, VideoType.AdultEpisode);
                file.SeriesId = series.Id;
                file.SeasonId = 91;
            }
            else if (type == VideoType.ChildEpisode)
            {
                var series = manager.AddOrUpdateVideoSeries(info.Name, false, VideoType.ChildEpisode);
                file.SeriesId = series.Id;
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
                file.SeriesId = 11;
                file.SeasonId = manager.AddOrUpdateSeason(11, "Сказки скаченные").Id;
            }
            else if (type == VideoType.Art && tgRecord != null)
            {
                file.SeriesId = 2038;
                file.SeasonId = manager.AddOrUpdateSeason(2038, file.Name).Id;
            }
            else
                Debug.Assert(false);

            file.Type = type;
        }

        private async Task ProcessTelegram(DbFile file, long tgFromId, VideoInfo info, SearchRecord record)
        {
            var result = @$"Название: {file.Name}
Длительность: {file.Duration}
Год: {file.Year}
Режиссер: {info.Director}
Описание: {file.Description}";

            var keyboard = new List<InlineKeyboardButton>
                {
                    new InlineKeyboardButton("Неправильный фильм! Удалить.") { CallbackData = CommandParser.GetMessageFromData(CommandType.Delete, record.Topic.Id.ToString()) },
                };

            await _botClient.SendTextMessageAsync(tgFromId, $"{result}", replyMarkup: new InlineKeyboardMarkup(keyboard));

            foreach (var item in _infos.Where(x => x.SearchSctring == record?.SearchSctring).ToList())
            {
                _infos.Remove(item);
                await _botClient.DeleteMessageAsync(tgFromId, item.MessageId);
            }
        }

        private void FillData(int id, VideoInfo info, 
            string downloadPath, FileStore.Domain.Models.VideoFile file)
        {
            try
            {
                _rutracker.FillFileInfo(file, info);
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }

            file.Name = _rutracker.ClearFromForeignOption(info.Name);
            file.IsDownloading = true;
            file.Path = downloadPath;
            file.Type = FileStore.Domain.Models.VideoType.Downloaded;
            file.VideoFileExtendedInfo.RutrackerId = id;
        }

        private async Task _botClient_OnMessage(ITelegramBotClient botClient, Message message)
        {
            var command = CommandParser.ParseCommand(message.Text);

            switch (command)
            {
                case CommandType.SetupVLC:
                    await SetupVLC(message.From.Id);
                    break;
                case CommandType.FixCover:
                    await UpdateCover(3, message.From.Id);
                    break;
                case CommandType.Series:
                    break;
                case CommandType.Film:
                    break;
                case CommandType.Unknown:
                    await ProcessUserInput(message, true);
                    break;
                default:
                    break;
            }

        }

        private async Task ProcessUserInput(Message message, bool filterThemes)
        {
            var text = message.Text;
            if (text.Contains("youtube") || text.Contains("youtu.be"))
            {
                await ShowYoutubeChoice(message);

                return;
            }

            await ProcessUserInput(text, message.From.Id, filterThemes);
        }

        private async Task ProcessUserInput(string text, long fromId, bool filterThemes)
        { 
            var infos = await _rutracker.FindTheme(text, filterThemes);

            if (!infos.Any())
                await _botClient.SendTextMessageAsync(new ChatId(fromId), $"Ничего не найдено");

            foreach (var info in infos)
            {
                var keyboard = new List<List<InlineKeyboardButton>>
                {
                 new List<InlineKeyboardButton>{
                    new InlineKeyboardButton("фильм") { CallbackData = CommandParser.GetMessageFromData(CommandType.Film, info.Id.ToString()) },
                    new InlineKeyboardButton("сериал") { CallbackData = CommandParser.GetMessageFromData(CommandType.Series, info.Id.ToString()) },
                    new InlineKeyboardButton("балет/опера") { CallbackData = CommandParser.GetMessageFromData(CommandType.Art, info.Id.ToString()) },
                    },
                 new List<InlineKeyboardButton>{
                    new InlineKeyboardButton("мультсериал") { CallbackData = CommandParser.GetMessageFromData(CommandType.ChildSeries, info.Id.ToString()) },
                    new InlineKeyboardButton("длинный мульт") { CallbackData = CommandParser.GetMessageFromData(CommandType.Animation, info.Id.ToString()) },
                    new InlineKeyboardButton("сказка") { CallbackData = CommandParser.GetMessageFromData(CommandType.FairyTale, info.Id.ToString()) },
                    new InlineKeyboardButton("аудиосказка") { CallbackData = CommandParser.GetMessageFromData(CommandType.AudioFairyTale, info.Id.ToString()) },
                } };
                var size = decimal.Round(info.SizeInBytes / 1024 / 1024 / 1024, 2, MidpointRounding.AwayFromZero);
                var title = info.Title;
                if (title.Contains("DVD9") && !title.Contains("DVD5"))
                    title = $"КОПИЯ ДИСКА {title}";

                var messageText = $"{size} GB | {info.DownloadsCount} | {info.CreatedAt.ToString("MM-yy")} | {title}";
                var tgMessage = await _botClient.SendTextMessageAsync(new ChatId(fromId),
                    messageText, replyMarkup: new InlineKeyboardMarkup(keyboard));

                _infos.Add(new SearchRecord { Topic = info, MessageId = tgMessage.MessageId, SearchSctring = text });
            }

            await AddSearchAllButton(text, fromId);
        }

        private async Task ShowYoutubeChoice(Message message)
        {
            var originalText = message.Text;
            var keyboard = new List<List<InlineKeyboardButton>>
                {
                 new List<InlineKeyboardButton>{
                    new InlineKeyboardButton("Посмотреть на один раз") { CallbackData = CommandParser.GetMessageFromData(CommandType.YoutubeWatchLater, originalText) },
                    new InlineKeyboardButton("Как положено") { CallbackData = CommandParser.GetMessageFromData(CommandType.YoutubeAsDesigned, originalText) },
                    }};

            var messageText = $"Как храним скачанное с ютуба?";
            var tgMessage = await _botClient.SendTextMessageAsync(new ChatId(message.From.Id),
                messageText, replyMarkup: new InlineKeyboardMarkup(keyboard), replyToMessageId:message.MessageId);
        }

        private async Task AddSearchAllButton(string text, long fromId)
        {
            var tgMessage = await _botClient.SendTextMessageAsync(new ChatId(fromId),
                "Нет ничего подходящего?", replyMarkup: new InlineKeyboardMarkup(new InlineKeyboardButton("Показать без фильтрации") { 
                    CallbackData = CommandParser.GetMessageFromData(CommandType.ShowAllSearchResult, text) }));
        }

        public async Task ProcessYoutubeVideo(string text, long fromId, Message message, bool watchLater)
        {
            try
            {
                var info = await YoutubeDownloader.GetInfo(text, Path.Combine(_config.RootDownloadFolder, "Youtube"));

                foreach (var record in info.Records)
                {
                    try
                    {
                        var scope = _serviceScopeFactory.CreateScope();
                        var fileService = scope.ServiceProvider.GetRequiredService<DbUpdateManager>();
                        fileService.AddFromYoutube(record.Value, info.ChannelName, watchLater);

                        var policy = Policy
                            .Handle<Exception>()
                            .WaitAndRetry(20, retryAttempt => TimeSpan.FromSeconds(10));

                        await policy.Execute(async () =>
                        {
                            record.Value.Path = record.Value.Path.Replace(" ", "");
                            await YoutubeDownloader.Download(record.Key, record.Value.Path);

                            fileService.YoutubeFinished(record.Value);

                            await NotifyDownloadEnded(fromId, record.Value);
                        });
                    }
                    catch (Exception ex)
                    {
                        NLog.LogManager.GetCurrentClassLogger().Error(ex);
                    }
                }
            }
            catch (Exception)
            {
                var tgMessage = await _botClient.SendTextMessageAsync(new ChatId(fromId),
                    "Ошибка, файл не скачан!", replyToMessageId: message.MessageId);
                return;
            }
        }

        private async Task UpdateCover(int count, long tgId)
        {
            var db = _GetDb();
            var filesToUpdateCoverByTg = db.VideoFiles
                .Where(x => x.Type != VideoType.Courses)
            //var filesToUpdateCoverByTg = db.VideoFiles.Where(x => x.Type == VideoType.Animation)
                .Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).OrderByDescending(x => x.Id).ToList();
            filesToUpdateCoverByTg = filesToUpdateCoverByTg.Where(x => x.Cover == null || x.Cover.Length < 20 * 1024).ToList();

            //var files = db.VideoFiles.Where(x => x.SeasonId == 202);
            //foreach (var file in files)
            //{
            //    file.Type = VideoType.Courses;
            //}
            //db.SaveChanges();

            if (!filesToUpdateCoverByTg.Any())
            {
                _botClient.SendTextMessageAsync(new ChatId(tgId), "Нечего обновлять");
            }

            foreach (var file in filesToUpdateCoverByTg.Take(count))
            {
                await SearchCoverForFile(file, tgId);
                DbUpdateManager.FillVideoProperties(file);
                await db.SaveChangesAsync();
            }
        }
    }
}
