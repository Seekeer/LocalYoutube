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

namespace API.FilmDownload
{
    public class SearchRecord
    {
        public SearchTopicInfo Topic { get; set; }
        public int MessageId { get; set; }
        public string SearchSctring { get; set; }
    }

    public class TgBot
    {
        private readonly IServiceScopeFactory _serviceScopeFactory;
        private readonly AppConfig _config;
        private readonly TelegramBotClient _botClient;
        private readonly RuTrackerUpdater _rutracker;
        private readonly List<SearchRecord> _infos = new List<SearchRecord>();
        private readonly Dictionary<string, SearchResult> _images = new Dictionary<string, SearchResult>();
        private readonly Dictionary<long, int> _tgSeasonDict = new Dictionary<long, int>(); 
        private readonly int _adminId = 176280269;
        public const string UPDATECOVER_MESSAGE = "Обновить обложку";
        private Timer _timer;

        public TgBot(AppConfig config, IServiceScopeFactory serviceScopeFactory)
        {
            _serviceScopeFactory = serviceScopeFactory;
            _config = config;
            _botClient = new TelegramBotClient(config.TelegramSettings.ApiKey);
            _rutracker = new RuTrackerUpdater(config);

            NLog.LogManager.GetCurrentClassLogger().Info($"Telegram bot created:{config.TelegramSettings.ApiKey}");

            SendAdminMessage($"Сервер стартанул");

            CreateTGDict();
        }

        private void CreateTGDict()
        {
            //var seriesDownload = db.Series.First(x => x.Id == 18);
            //var seasonA = manager.AddOrUpdateSeason(seriesDownload, "Алена");
            //var seasonD = manager.AddOrUpdateSeason(seriesDownload, "Дима");

            // Helen
            _tgSeasonDict.Add(360495063, 200);
            // DIMA
            _tgSeasonDict.Add(176280269, 201);
        }

        private async Task SendAdminMessage(string message)
        {
            await _botClient.SendTextMessageAsync(
                            chatId: _adminId,
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
                    await FillVideoFileId(id, 111, null, item.SavePath);
                }
                catch (Exception ex)
                {
                }
            }
        }

        private  void TimerCallback(Object o)
        {
            // Discard the result
            _ = DoAsyncPing();
        }

        private async Task DoAsyncPing()
        {
            NLog.LogManager.GetCurrentClassLogger().Info("DoAsyncPing");
            var db = _GetDb();
            var manager = new DbUpdateManager(db);

            var updated = manager.UpdateDownloading((info) => info.IsDownloading);

            NLog.LogManager.GetCurrentClassLogger().Info($"updated count: {updated.Count()}");

            foreach (var item in updated)
            {
                if (!_tgSeasonDict.TryGetKey(item.SeasonId, out var telegramId))
                    telegramId = _adminId;

                await _botClient.SendTextMessageAsync(new ChatId(telegramId), $"Закончена закачка {item.Name} {Environment.NewLine} http://192.168.1.55:51951/api/Files/getFileById?fileId={item.Id}");
            }
        }

        private FileStore.Infrastructure.Context.VideoCatalogDbContext _GetDb()
        {
            return _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<FileStore.Infrastructure.Context.VideoCatalogDbContext>();
        }

        public async Task SearchCoverForFile(VideoFile file, long tgAccountId)
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
                    keyboard.Add(new InlineKeyboardButton($"Использовать эту обложку") { CallbackData = guid });
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
                    GetRequiredService<IFileRepository>();

                var file = await fileRepo.GetById(data.File.Id);

                ImageConverter converter = new ImageConverter();
                var bytes = (byte[])converter.ConvertTo(data.Bitmap, typeof(byte[]));

                file.VideoFileExtendedInfo.Cover = bytes;
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

        private async Task AddTorrent(string data, long fromId)
        {
            if (!int.TryParse(data, out var id))
                return;

            //await _botClient.SendTextMessageAsync(new ChatId(_config.TelegramSettings.ChatId), update.CallbackQuery.Data);
            var record = _infos.FirstOrDefault(x => x.Topic.Id == id);
            var searchInfo = record.Topic;

            NLog.LogManager.GetCurrentClassLogger().Info($"Got info for thread:{searchInfo.Id}|{searchInfo.Title}");
            IServiceScope scope = await FillVideoFileId(id, fromId, record);
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
                        await this._botClient_OnMessage(botClient, update.Message);
                        break;
                    case Tg.UpdateType.InlineQuery:
                        break;
                    case Tg.UpdateType.ChosenInlineResult:
                        break;
                    case Tg.UpdateType.CallbackQuery:
                        if (_images.ContainsKey(update.CallbackQuery.Data))
                            await UpdateFile(_images[update.CallbackQuery.Data]);
                        else
                            await AddTorrent(update.CallbackQuery.Data, update.CallbackQuery.From.Id);
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

                await _botClient.SendTextMessageAsync(new ChatId(userId), $"Ошибка при обработке торрента",
                    null, null, null, null, messageId);
            }
        }

        private async Task<IServiceScope> FillVideoFileId(int rutrackerId, long tgFromId, SearchRecord record, string downloadPath = null)
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
                SeasonId = 91
            };

            if (_tgSeasonDict.TryGetValue(tgFromId, out var seasonId))
                file.SeasonId = seasonId;

            FillData(rutrackerId, info, downloadPath, file);

            var result =@$"Название: {file.Name}
Year: {file.Year}
Director: {info.Director}
Duration: {file.Duration}
Id: {info.Id}
Description: {file.Description}";

            var scope = _serviceScopeFactory.CreateScope();
            var fileService = scope.ServiceProvider.GetRequiredService<IFileRepository>();
            await fileService.Add(file);

            await _botClient.SendTextMessageAsync(new ChatId(tgFromId), $"{result}");

            foreach (var item in _infos.Where(x => x.SearchSctring == record?.SearchSctring).ToList())
            {
                _infos.Remove(item);
                await _botClient.DeleteMessageAsync(_config.TelegramSettings.ChatId, item.MessageId);
            }

            if(file.Cover?.Length < 20 * 1024)
                await SearchCoverForFile(file, tgFromId);

            return scope;
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
            //using var scope1 = _serviceScopeFactory.CreateScope();
            //var db = scope1.ServiceProvider.GetRequiredService<FileStore.Infrastructure.Context.VideoCatalogDbContext>();
            //var files = db.Files.Include(x => x.VideoFileExtendedInfo).Where(x => x.VideoFileExtendedInfo.Cover.Length > 0 && x.VideoFileExtendedInfo.RutrackerId > 0).ToList();
            //foreach (var file in files)
            //{
            //    var info = await _rutracker.FillInfo(file.VideoFileExtendedInfo.RutrackerId);
            //    file.VideoFileExtendedInfo.Cover = info.Cover;
            //    file.Name = info.Name;
            //    file.Duration = info.Duration;
            //}

            //db.SaveChanges();

            //return;

            //db.SaveChanges();

            //if(int.TryParse(message.Text, out var id))
            //{
            //    IServiceScope scope = await FillVideoFileId(id, record, searchInfo);

            //    var info = await _rutracker.(message.Text);

            //}
            //else 

            //await ReAddExistingTopics();

            //var res = await _rutracker.FillInfo(3399749);
            if (message.Text.Contains(UPDATECOVER_MESSAGE))
            {
                await UpdateCover(3, message.From.Id);

                return;
            }
            else if (message.Text.Contains("youtube"))
            {
                var file = await YoutubeDownloader.GetInfo(message.Text, Path.Combine(_config.RootDownloadFolder, "Youtube"));

                var scope = _serviceScopeFactory.CreateScope();
                var fileService = scope.ServiceProvider.GetRequiredService<DbUpdateManager>();
                fileService.AddFromYoutube(file.File, file.ChannelName);

                await _botClient.SendTextMessageAsync(new ChatId(message.From.Id), $"Начата загрузка видео с ютуба {Environment.NewLine}{file.File.Name} ");

                Task.Run(async () =>
                {
                    await YoutubeDownloader.Download(message.Text, file.File.Path);

                    fileService.YoutubeFinished(file.File);
                    await _botClient.SendTextMessageAsync(new ChatId(message.From.Id), $"Закончена загрузка видео {Environment.NewLine}{file.File.Name}");
                });

                return;
            }

            var infos = await _rutracker.FindTheme(message.Text);

            if(!infos.Any())
                await _botClient.SendTextMessageAsync(new ChatId(message.From.Id), $"Ничего не найдено");

            foreach (var info in infos)
            {
                var keyboard = new List<InlineKeyboardButton>();
                keyboard.Add(new InlineKeyboardButton("Добавить фильм") { CallbackData = (info.Id).ToString() });
                var size = decimal.Round(info.SizeInBytes / 1024 / 1024 / 1024, 2, MidpointRounding.AwayFromZero);
                var messageText = $"{size} GB | {info.DownloadsCount} | {info.CreatedAt.ToString("MM-yy")} | {info.Title}";
                var tgMessage = await _botClient.SendTextMessageAsync(new ChatId(message.From.Id), 
                    messageText, replyMarkup: new InlineKeyboardMarkup(keyboard));

                _infos.Add(new SearchRecord { Topic = info, MessageId = tgMessage.MessageId, SearchSctring = message.Text });
            }
        }

        private async Task UpdateCover(int count, long tgId)
        {
            var db = _GetDb();
            var filesToUpdateCoverByTg = db.VideoFiles.Where(x => x.Type == VideoType.FairyTale)
            //var filesToUpdateCoverByTg = db.VideoFiles.Where(x => x.Type == VideoType.Animation)
                .Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfo).OrderByDescending(x => x.Id).ToList();
            filesToUpdateCoverByTg = filesToUpdateCoverByTg.Where(x => x.Cover == null || x.Cover.Length < 20 * 1024).ToList();
            foreach (var file in filesToUpdateCoverByTg.Take(count))
            {
                await SearchCoverForFile(file, tgId);
                DbUpdateManager.FillVideoProperties(file);
                await db.SaveChangesAsync();
            }
        }
    }
}
