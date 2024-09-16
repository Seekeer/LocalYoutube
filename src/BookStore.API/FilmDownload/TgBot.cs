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
using static API.FilmDownload.TgBot;
using QBittorrent.Client;
using Google.Apis.CustomSearchAPI.v1.Data;
using API.Resources;
using NLog.Web.LayoutRenderers;
using System.Xml.Linq;
using Telegram.Bot.Polling;
using OpenQA.Selenium.DevTools.V126.CSS;
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
        public const string START_ANYDESK_MESSAGE = "Start anydesk";
        public const string STOP_ANYDESK_MESSAGE = "Stop anydesk";
        public const string SUSPEND_PC_Message = "Suspend PC";
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
            InitCommands();
        }

        private async Task InitCommands()
        {
            var commands = new List<BotCommand>();
            commands.Add(new BotCommand { Command = "newcover", Description = "Обновить обложку для файла" });

            await _botClient.SetMyCommandsAsync(commands);
        }

        internal IEnumerable<TgLink> GetDict()
        {
            return _tgSeasonDict;
        }

        private void CreateTGDict()
        {
            var db = _GetDb();
            var manager = new DbUpdateManager(db);
            var seriesDownload = db.Series.First(x => x.Id == 18);

            // TODO hardcodes
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

        private List<List<KeyboardButton>> GetKeyboardButtons(bool isAdmin)
        {
            var keyboard = new List<List<KeyboardButton>>();

            if (isAdmin)
            {
                var LTlist = new List<KeyboardButton>
                {
                    new KeyboardButton(UPDATECOVER_MESSAGE),
                    new KeyboardButton(SETUP_VLC_Message)
                };
                keyboard.Add(LTlist);

                keyboard.Add(new List<KeyboardButton>
                {
                    new KeyboardButton(SUSPEND_PC_Message),
                    new KeyboardButton(START_ANYDESK_MESSAGE),
                    new KeyboardButton(STOP_ANYDESK_MESSAGE)
                });
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
        }


        public async Task NotifyDownloadProblem(long telegramId, string link)
        {
            await _botClient.SendTextMessageAsync(new ChatId(telegramId), $"Проблема с закачкой видео {link}. Попробуй скачать позже вручную.");
        }

        private FileStore.Infrastructure.Context.VideoCatalogDbContext _GetDb()
        {
            return _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<FileStore.Infrastructure.Context.VideoCatalogDbContext>();
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
                await fileRepo.UpdateAsync(file);

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

        private async Task AddTorrent(string data, long fromId, VideoType? type, AudioType? audioType = null)
        {
            if (!int.TryParse(data, out var id))
                return;

            //await _botClient.SendTextMessageAsync(new ChatId(_config.TelegramSettings.ChatId), update.CallbackQuery.Data);
            var record = _infos.FirstOrDefault(x => x.Topic.Id == id);
            var searchInfo = record.Topic;

            NLog.LogManager.GetCurrentClassLogger().Info($"Got info for thread:{searchInfo.Id}|{searchInfo.Title}");

            if (type != null)
            {
                var filler = new FillVideoFileByTorrent(_rutracker, _config, _botClient, _serviceScopeFactory, this, type.Value);
                await filler.CreateDbFile(id, fromId, record);
            }
            else
            {
                var filler = new FillAudioFileByTorrent(_rutracker, _config, _botClient, _serviceScopeFactory, this, audioType.Value);
                await filler.CreateDbFile(id, fromId, record);
            }
        }

        public static async Task HandleErrorAsync(ITelegramBotClient botClient, Exception exception, CancellationToken cancellationToken)
        {
            try
            {
                NLog.LogManager.GetCurrentClassLogger().Info(exception);
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
                        if (!IsAuthorValid(update.Message.From.Id))
                            return;

                        if(update.Message.ReplyToMessage != null)
                            await ProcessReply(update.Message);
                        else if (_tgSeasonDict.Any(x => x.TgId == update.Message.From.Id))
                            await this.ProcessMessage(botClient, update.Message);
                        break;
                    case Tg.UpdateType.ChosenInlineResult:
                        break;
                    case Tg.UpdateType.CallbackQuery:
                        if (!IsAuthorValid(update.CallbackQuery.From.Id))
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
                            case CommandType.AudioBook:
                                await AddTorrent(command.Data, update.CallbackQuery.From.Id, null,  AudioType.AudioBook);
                                break;
                            case CommandType.AudioFairyTale:
                                await AddTorrent(command.Data, update.CallbackQuery.From.Id, null, AudioType.AudioBook);
                                break;
                            case CommandType.ShowAllSearchResult:
                            case CommandType.SearchAudioBook:
                                await TryRutrackerDownload(command.Data, update.CallbackQuery.From.Id, command.Type);
                                break;
                            case CommandType.DownloadAsDesigned:
                                // Do nothign
                                break;
                            case CommandType.DownloadIndia:
                                await MoveToSeries(command.Data, SeasonNames.India);
                                break;
                            case CommandType.DownloadCossacks:
                                await MoveToSeries(command.Data, SeasonNames.Cossacks);
                                break;
                            case CommandType.DownloadEot:
                                await MoveToSeries(command.Data, SeasonNames.Eot);
                                break;
                            case CommandType.DownloadIt:
                                await MoveToSeries(command.Data, SeasonNames.It);
                                break;
                            case CommandType.DownloadKurginyan:
                                await MoveToSeries(command.Data, SeasonNames.Kurginyan);
                                break;
                            case CommandType.DownloadPremier:
                                await DownloadedForPremier(command.Data);
                                break;
                            case CommandType.DownloadOneTime:
                                await MoveToSeries(command.Data, SeasonNames.OneTime);
                                break;
                            case CommandType.DeleteByRutracker:
                                await DeleteFileByRutrackerId(update.CallbackQuery.Id, command.Data);
                                break;
                            case CommandType.DeleteById:
                                await DeleteFileById(update.CallbackQuery.Id, command.Data);
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
                        replyToMessageId: messageId);
                }
                catch (Exception)
                {
                }
            }
        }

        private bool IsAuthorValid(long id)
        {
            return _tgSeasonDict.Any(x => x.TgId == id);
        }

        private async Task ProcessReply(Message message)
        {
            var task = _downloadTasks.FirstOrDefault(x => x.Value.QuestionMessageId == message.ReplyToMessage.MessageId);

            if (EqualityComparer<KeyValuePair<string, TgDownloadTask>>.Default.Equals(task, default(KeyValuePair<string, TgDownloadTask>)))
                return;


            var scope = _serviceScopeFactory.CreateScope();
            using (var fileService = scope.ServiceProvider.GetRequiredService<IVideoFileRepository>())
            {
                var file = await fileService.GetById(task.Value.FileId);
                file.Name = message.Text;
                await fileService.UpdateAsync(file);
            }
        }

        private async Task SetupVLC(long id)
        {
            var message = @$"1. Положи файлы из bat.zip в C:\Program Files\VideoLAN\VLC 
2. Запусти vlc-protocol-register.bat";

            using (var stream = System.IO.File.OpenRead(@"Assets\bat.zip"))
            {
                var file = new InputFileStream(stream, "bat.zip");

                await _botClient.SendDocumentAsync(
                    caption: message,
                    chatId: id,
                    document: file
                );
            }
        }

        private async Task DeleteFileById(string callbackId, string idStr)
        {
            try
            {
                var id = int.Parse(idStr);
                using var fileService = _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<IDbFileService>();
                    await fileService.Remove(id);
                await _botClient.AnswerCallbackQueryAsync(callbackId, "Видео удалено");
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
                await _botClient.AnswerCallbackQueryAsync(callbackId, "Ошибка при удалении");
            }
        }

        private async Task DeleteFileByRutrackerId(string callbackId, string rutrackerId)
        {
            try
            {
                await _rutracker.DeleteTorrent(rutrackerId);

                var db = _GetDb();
                var id = int.Parse(rutrackerId);
                var file = db.FilesInfo.FirstOrDefault(x => x.RutrackerId == id);
                if (file != null)
                {
                    db.Entry(file).State = EntityState.Detached;
                    using var fileService = _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<IDbFileService>();
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


        public async Task ProcessTelegram(DbFile file, long tgFromId, SearchRecord record)
        {
            var watchString = "Посмотреть".AddLink(file.GetUrl(_config));
            var result = @$"Название: {file.Name}
Длительность: {file.Duration}
{watchString}
Год: {file.Year}
Описание: {file.Description}";

            var keyboard = new List<InlineKeyboardButton>
                {
                    new InlineKeyboardButton("Неправильный фильм! Удалить.") { CallbackData = CommandParser.GetMessageFromData(CommandType.DeleteByRutracker, record.Topic.Id.ToString()) },
                };

            await _botClient.SendTextMessageAsync(tgFromId, $"{result}", replyMarkup: new InlineKeyboardMarkup(keyboard));

            foreach (var item in _infos.Where(x => x.SearchSctring == record?.SearchSctring).ToList())
            {
                _infos.Remove(item);
                await _botClient.DeleteMessageAsync(tgFromId, item.MessageId);
            }
        }

        public async Task SearchCoverForFile(DbFile file, long tgAccountId)
        {
            var search = new SearchEngine("f228f7e30451842e8", "AIzaSyB9gRWRoQRXZiLcX7ZUACwi-Smm5L8R-Mg");
            var results = await search.Search($"фильм {file.Name} {file.VideoFileExtendedInfo.Year}", file.Name);

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
                        new InputFileUrl(image.Url),
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

        private async Task ProcessMessage(ITelegramBotClient botClient, Message message)
        {
            NLog.LogManager.GetCurrentClassLogger().Info($"Tg received from {message.From.Id} message {message.Text}");

            var command = CommandParser.GetDataFromMessage(message.Text);

            switch (command.Type)
            {
                case CommandType.SetupVLC:
                    await SetupVLC(message.From.Id);
                    break;
                case CommandType.FixCover:
                    await UpdateCover(3, message.From.Id);
                    break;
                case CommandType.SuspendPC:
                    await SuspendPC(message.From.Id);
                    break;
                case CommandType.StartAnydesk:
                    await StartAnydesk(message.From.Id);
                    break;
                case CommandType.StopAnydesk:
                    await StopAnydesk(message.From.Id);
                    break;
                case CommandType.Series:
                    break;
                case CommandType.Film:
                    break;
                case CommandType.Unknown:
                    await ProcessUserInput(message);
                    break;
                case CommandType.UpdateCover:
                    if (await UpdateCover(command))
                        await _botClient.SendTextMessageAsync(message.From.Id, "Обложка обновлена", replyToMessageId: message.MessageId);
                    break;
                case CommandType.Rename:
                    if (await Rename(command))
                        await _botClient.SendTextMessageAsync(message.From.Id, "Файл переименован", replyToMessageId: message.MessageId);
                    break;
                    break;
                default:
                    break;
            }
        }

        private async Task StartAnydesk(long id)
        {
            LocalPCHelper.StartAnydesk();
        }

        private async Task StopAnydesk(long id)
        {
            LocalPCHelper.StopAnydesk();
        }

        private async Task SuspendPC(long id)
        {
            LocalPCHelper.SuspendPC();
        }

        private async Task ProcessUserInput(Message message)
        {
            if (string.IsNullOrEmpty(message.Text)) 
                return;

            var processMessage = await _botClient.SendTextMessageAsync(message.From.Id, "Начата обработка запроса", replyToMessageId: message.MessageId);
            var lines = message.Text.SplitByNewLine();

            var tasks = TgDownloadTask.IsDownloadCommand(lines) ? 
                TgDownloadTask.ParseTasks(message, lines) :
                lines.Select(line => new TgDownloadTask(message.MessageId, message.From.Id, line));

            var errorLines = new List<string>();
            foreach (var task in tasks)
            {
                try
                {
                    _downloadTasks.Add(task.Id, task);

                    if (DownloaderFabric.CanDownload(task))
                    {
                        var downloader = DownloaderFabric.CreateDownloader(task, _config);
                        task.DownloadType = downloader.DownloadType;

                        await downloader.DownloadAndProcess(task, _serviceScopeFactory,
                            async ex =>
                            {
                                NLog.LogManager.GetCurrentClassLogger().Error(ex);
                                errorLines.Add(task.OriginalLine);
                            },
                            async videoFile =>
                            {
                                await NotifyBotDownloadEnded(videoFile, task);
                            });
                    }
                    else
                    {
                        await TryRutrackerDownload(task.OriginalLine, message.From.Id);
                        await _botClient.DeleteMessageAsync(message.From.Id, processMessage.MessageId);
                    }
                }
                catch (Exception ex)
                {
                    NLog.LogManager.GetCurrentClassLogger().Error(ex);
                    errorLines.Add(task.OriginalLine);
                }
            }

            var totalCount = tasks.Count();
            var endMessage = $"Скачивание завершено. Скачано {totalCount - errorLines.Count}/{totalCount}";
            if (errorLines.Any())
                endMessage += Environment.NewLine + $"Ошибка, файл не скачан:{Environment.NewLine}{string.Join(Environment.NewLine, errorLines)}";

            await _botClient.SendTextMessageAsync(new ChatId(message.From.Id), endMessage, 
                replyToMessageId: message.MessageId, disableWebPagePreview: true);
            await _botClient.DeleteMessageAsync(message.From.Id, processMessage.MessageId);
        }

        private async Task TryRutrackerDownload(string text, long fromId, CommandType? type = null)
        { 
            var infos = await _rutracker.FindTheme(text, type);

            if (!infos.Any())
                await _botClient.SendTextMessageAsync(new ChatId(fromId), $"Ничего не найдено");

            foreach (var info in infos)
            {
                List<List<InlineKeyboardButton>> keyboard = CreateKeyboard(info, type);
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

        private static List<List<InlineKeyboardButton>> CreateKeyboard(SearchTopicInfo info, CommandType? type)
        {
            switch (type)
            {
                case CommandType.SearchAudioBook:
                    return new List<List<InlineKeyboardButton>>
                        {
                            new List<InlineKeyboardButton>{
                                new InlineKeyboardButton("Аудиосказка") { CallbackData = CommandParser.GetMessageFromData(CommandType.AudioFairyTale, info.Id.ToString()) },
                                new InlineKeyboardButton("Аудиокнига") { CallbackData = CommandParser.GetMessageFromData(CommandType.AudioBook, info.Id.ToString()) },
                        }
                    };
                default:
                    return new List<List<InlineKeyboardButton>>
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
                            // TODO audio download from tracker
                        }
                    };
            }
        }

        private Dictionary<string, TgDownloadTask> _downloadTasks = new Dictionary<string, TgDownloadTask>();

        private async Task AddSearchAllButton(string text, long fromId)
        {
            try
            {
                var tgMessage = await _botClient.SendTextMessageAsync(new ChatId(fromId),
                    "Нет ничего подходящего?", replyMarkup:
                        new InlineKeyboardMarkup(new List<InlineKeyboardButton>{
                            new InlineKeyboardButton("Показать без фильтрации"){CallbackData = CommandParser.GetMessageFromData(CommandType.ShowAllSearchResult, text)},
                            new InlineKeyboardButton("Искать аудиокниги") {CallbackData = CommandParser.GetMessageFromData(CommandType.SearchAudioBook, text)},
                        }));
            }
            catch (Exception ex)
            {
            }
        }

        private async Task MoveToSeries(string taskId, string seriesName)
        {
            var task = _downloadTasks[taskId];
            var service = _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<IVideoFileService>();
            await service.MoveToAnotherSeriesByNameAsync(task.FileId, seriesName, false);

            await _botClient.EditMessageReplyMarkupAsync(new ChatId(task.FromId), task.QuestionMessageId);
        }

        private async Task DownloadedForPremier(string taskId)
        {
           var task = _downloadTasks[taskId];
            var fileRepo = _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<IVideoFileRepository>();
            var file = await fileRepo.GetById(task.FileId);

            var newPath = await new VideoHelper(_config).EncodeToX264(file.Path);

            fileRepo.RemoveFileCompletely(task.FileId);
            await _botClient.DeleteMessageAsync(new ChatId(task.FromId), task.QuestionMessageId);
        }

        public async Task NotifyDownloadEnded(long telegramId, DbFile item)
        {
            var keyboard = new List<InlineKeyboardButton>
                {
                    new InlineKeyboardButton("Неправильный фильм! Удалить") { CallbackData = CommandParser.GetMessageFromData(CommandType.DeleteByRutracker, item.Id.ToString()) },
                };

            await _botClient.SendTextMessageAsync(new ChatId(telegramId), GetDownloadEndMessage(item),
                parseMode: Tg.ParseMode.Markdown, replyMarkup: new InlineKeyboardMarkup(keyboard));
        }

        private string GetDownloadEndMessage(DbFile file) 
        {
            var linkText = "Посмотреть".AddLinkWithNewLine(file.GetUrl(_config));
            var message = $"Закончена закачка {file.Name} в {file.Series?.Name.MakeBold()}|{file.Season?.Name.MakeBold()}{linkText}";
            return message;
        }

        private async Task NotifyBotDownloadEnded(DbFile item, TgDownloadTask task)
        {
            var keyboard = new List<List<InlineKeyboardButton>>
                {
                 new List<InlineKeyboardButton>{
                    new InlineKeyboardButton(SeasonNames.OneTime) { CallbackData = CommandParser.GetMessageFromData(CommandType.DownloadOneTime, task.Id) },
                    new InlineKeyboardButton(SeasonNames.AsDesigned) { CallbackData = CommandParser.GetMessageFromData(CommandType.DownloadAsDesigned, task.Id) },
                    new InlineKeyboardButton(SeasonNames.Premiere) { CallbackData = CommandParser.GetMessageFromData(CommandType.DownloadPremier, task.Id) },
                    new InlineKeyboardButton(SeasonNames.Delete) { CallbackData = CommandParser.GetMessageFromData(CommandType.DeleteById, item.Id.ToString()) },
                 },
                 new List<InlineKeyboardButton>{
                    new InlineKeyboardButton(SeasonNames.India) { CallbackData = CommandParser.GetMessageFromData(CommandType.DownloadIndia, task.Id) },
                    new InlineKeyboardButton(SeasonNames.Cossacks) { CallbackData = CommandParser.GetMessageFromData(CommandType.DownloadCossacks, task.Id) },
                    new InlineKeyboardButton(SeasonNames.Kurginyan) { CallbackData = CommandParser.GetMessageFromData(CommandType.DownloadKurginyan, task.Id) },
                    new InlineKeyboardButton(SeasonNames.Eot) { CallbackData = CommandParser.GetMessageFromData(CommandType.DownloadEot, task.Id) },
                    new InlineKeyboardButton(SeasonNames.It) { CallbackData = CommandParser.GetMessageFromData(CommandType.DownloadIt, task.Id) },
                    }};

            var tgMessage =  await _botClient.SendTextMessageAsync(new ChatId(task.FromId), 
                $"{GetDownloadEndMessage(item)}{Environment.NewLine}Как храним скачанное?",
                replyToMessageId: task.OriginalMessageId,
                disableWebPagePreview: true,
                parseMode: Tg.ParseMode.Markdown,
                replyMarkup: new InlineKeyboardMarkup(keyboard));

            task.QuestionMessageId = tgMessage.MessageId;
        }


        private async Task<bool> Rename(TgCommand command)
        {
            using (var fileService = _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<IVideoFileService>())
            {
                var fileId = int.Parse(command.GetDataParts().First());
                var file = await fileService.GetById(fileId);

                file.Name = command.GetDataParts().Last();
            }

            return true;
        }

        private async Task<bool> UpdateCover(TgCommand command)
        {
            using (var fileService = _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<IVideoFileService>())
            {
                var fileId = int.Parse(command.GetDataParts().First());
                var file =await fileService.GetById(fileId);

                file.VideoFileExtendedInfo.SetCoverByUrl(command.GetDataParts().Last());
            }

            return true;
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
                await _botClient.SendTextMessageAsync(new ChatId(tgId), "Нечего обновлять");
            }

            foreach (var file in filesToUpdateCoverByTg.Take(count))
            {
                await SearchCoverForFile(file, tgId);
                //DbUpdateManager.FillVideoProperties(file);
                await db.SaveChangesAsync();
            }
        }

        internal async Task NotifyDownloaded(IEnumerable<DbFile> updated)
        {
            foreach (var item in updated)
            {
                var telegramId = _config.TelegramSettings.InfoGroupId;
                var telegramLink = _tgSeasonDict.FirstOrDefault(x => x.FilmSeasonId == item.SeriesId);
                if (telegramLink != null)
                    telegramId = telegramLink.TgId;

                await NotifyDownloadEnded(telegramId, item);
            }
        }

    }
}
