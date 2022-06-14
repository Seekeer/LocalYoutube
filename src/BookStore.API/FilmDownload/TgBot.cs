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

namespace API.FilmDownload
{
    public class TgBot
    {
        private readonly IServiceScopeFactory _serviceScopeFactory;
        private readonly AppConfig _config;
        private readonly TelegramBotClient _botClient;
        private readonly RuTrackerUpdater _rutracker;
        private readonly List<SearchTopicInfo> _infos = new List<SearchTopicInfo>();

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

            var searchInfo = _infos[id];

            var info = await _rutracker.FillInfo(searchInfo);
            var downloadPath = Path.Combine(_config.RootDownloadFolder,  Guid.NewGuid().ToString().Substring(0,5));
            await _rutracker.StartDownload(searchInfo, downloadPath);
            var file = new FileStore.Domain.Models.VideoFile
            {
                SeriesId = 1030,
                SeasonId = 1085
            };
            file.VideoFileExtendedInfo.Description = info.Description;
            file.VideoFileExtendedInfo.Cover = info.Cover;
            file.VideoFileExtendedInfo.Genres = info.Genres;
            file.VideoFileExtendedInfo.Year = info.Year;
            file.VideoFileExtendedInfo.RutrackerId = info.Id;
            file.Name = info.Name;
            file.IsDownloading = true;
            file.Path = downloadPath;
            file.Type = FileStore.Domain.Models.VideoType.Downloaded;

            using var scope = _serviceScopeFactory.CreateScope();
            var fileService = scope.ServiceProvider.GetRequiredService<IFileRepository>();
            await fileService.Add(file);

            await _botClient.SendTextMessageAsync(new ChatId(_config.TelegramSettings.ChatId), $"Начата закачка {file.Name}");
        }

        private async Task _botClient_OnMessage(ITelegramBotClient botClient, Message message)
        {
            var infos = await _rutracker.FindTheme(message.Text);

            foreach (var info in infos.OrderByDescending(x => x.SizeInBytes).Take(10))
            {
                _infos.Add(info);

                var keyboard = new List<InlineKeyboardButton>();
                keyboard.Add(new InlineKeyboardButton("Добавить фильм") { CallbackData = (_infos.Count -1).ToString() });
                var size = decimal.Round(info.SizeInBytes / 1024 / 1024 / 1024, 2, MidpointRounding.AwayFromZero);
                var messageText = $"{size} GB | {info.DownloadsCount} | {info.CreatedAt.ToString("MM-yy")} | {info.Title}";
                await _botClient.SendTextMessageAsync(new ChatId(_config.TelegramSettings.ChatId), 
                    messageText, replyMarkup: new InlineKeyboardMarkup(keyboard));
            }
        }
    }
}
