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

namespace API.FilmDownload
{
    public struct SearchRecord
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
        private Timer _timer;

        public TgBot(AppConfig config, IServiceScopeFactory serviceScopeFactory)
        {
            _serviceScopeFactory = serviceScopeFactory;
            _config = config;
            _botClient = new TelegramBotClient(config.TelegramSettings.ApiKey);
            _rutracker = new RuTrackerUpdater(config);

            NLog.LogManager.GetCurrentClassLogger().Info($"Telegram bot created:{config.TelegramSettings.ApiKey}");
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

        private  void TimerCallback(Object o)
        {
            // Discard the result
            _ = DoAsyncPing();
        }

        private async Task DoAsyncPing()
        {
            var db = _serviceScopeFactory.CreateScope().ServiceProvider.GetRequiredService<FileStore.Infrastructure.Context.VideoCatalogDbContext>();
            var manager = new DbUpdateManager(db);

            var updated = manager.UpdateSeason(0, (info) => info.IsDownloading);

            foreach (var item in updated)
            {
                var telegramId = 0;
                switch (item.SeasonId)
                {
                    case 2102:
                        telegramId = 176280269;
                        break;
                    case 2097:
                        telegramId = 176280269;
                        break;
                    case 2103:
                        telegramId = 360495063;
                        break;
                    default:
                        break;
                }

                await _botClient.SendTextMessageAsync(new ChatId(telegramId), $"Закончена закачка {item.Name}");
            }
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
                        await ExecuteCallback(botClient, update);
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
            }
        }

        private async Task ExecuteCallback(ITelegramBotClient botClient, Update update)
        {
            if (!int.TryParse(update.CallbackQuery.Data, out var id))
                return;

            //await _botClient.SendTextMessageAsync(new ChatId(_config.TelegramSettings.ChatId), update.CallbackQuery.Data);
            var record = _infos.FirstOrDefault(x => x.Topic.Id == id);
            var searchInfo = record.Topic;

            NLog.LogManager.GetCurrentClassLogger().Info($"Got info for thread:{searchInfo.Id}|{searchInfo.Title}");
            IServiceScope scope = await FillVideoFileId(id, record, searchInfo, update);
        }

        private async Task<IServiceScope> FillVideoFileId(int id, SearchRecord record, SearchTopicInfo searchInfo, Update update)
        {
            var info = await _rutracker.FillInfo(searchInfo.Id);

            var downloadPath = Path.Combine(_config.RootDownloadFolder, searchInfo.Id.ToString());
            await _rutracker.StartDownload(searchInfo, downloadPath);

            var file = new FileStore.Domain.Models.VideoFile
            {
                SeriesId = 1033,
                SeasonId = 2097
            };

            if (update.CallbackQuery.From.Id == 176280269)
                file.SeasonId = 2102;
            else if (update.CallbackQuery.From.Id == 360495063)
                file.SeasonId = 2103;

            FillData(id, info, downloadPath, file);

            var result =@$"Название: {file.Name}
Year: {file.Year}
Director: {info.Director}
Duration: {file.Duration}
Description: {file.Description}";

            var scope = _serviceScopeFactory.CreateScope();
            var fileService = scope.ServiceProvider.GetRequiredService<IFileRepository>();
            await fileService.Add(file);

            await _botClient.SendTextMessageAsync(new ChatId(_config.TelegramSettings.ChatId), $"{result}");

            foreach (var item in _infos.Where(x => x.SearchSctring == record.SearchSctring).ToList())
            {
                _infos.Remove(item);
                await _botClient.DeleteMessageAsync(_config.TelegramSettings.ChatId, item.MessageId);
            }

            return scope;
        }

        private void FillData(int id, VideoInfo info, 
            string downloadPath, FileStore.Domain.Models.VideoFile file)
        {
            _rutracker.FillFileInfo(file, info);

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
            if (message.Text.Contains("youtube"))
            {
                var file = await YoutubeDownloader.GetInfo(message.Text, Path.Combine(_config.RootDownloadFolder, "Youtube"));

                var scope = _serviceScopeFactory.CreateScope();
                var fileService = scope.ServiceProvider.GetRequiredService<DbUpdateManager>();
                fileService.AddFromYoutube(file.File, file.ChannelName);

                YoutubeDownloader.Download(message.Text, file.File.Path);

                return;
            }

            var infos = await _rutracker.FindTheme(message.Text);

            if(!infos.Any())
                await _botClient.SendTextMessageAsync(new ChatId(_config.TelegramSettings.ChatId), $"Ничего не найдено");

            foreach (var info in infos)
            {
                var keyboard = new List<InlineKeyboardButton>();
                keyboard.Add(new InlineKeyboardButton("Добавить фильм") { CallbackData = (info.Id).ToString() });
                var size = decimal.Round(info.SizeInBytes / 1024 / 1024 / 1024, 2, MidpointRounding.AwayFromZero);
                var messageText = $"{size} GB | {info.DownloadsCount} | {info.CreatedAt.ToString("MM-yy")} | {info.Title}";
                var tgMessage = await _botClient.SendTextMessageAsync(new ChatId(_config.TelegramSettings.ChatId), 
                    messageText, replyMarkup: new InlineKeyboardMarkup(keyboard));

                _infos.Add(new SearchRecord { Topic = info, MessageId = tgMessage.MessageId, SearchSctring = message.Text });
            }
        }
    }
}
