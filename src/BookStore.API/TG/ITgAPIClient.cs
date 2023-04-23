using API.FilmDownload;
using FileStore.API;
using FileStore.Infrastructure.Context;
using Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Polly;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using TL;
using WTelegram;

namespace API.TG
{
    public interface ITgAPIClient
    {
        public Task Start();
    }

    internal class TgAPIClient : ITgAPIClient
    {
        public TgAPIClient(IMessageProcessor messageProcessor, AppConfig config)
        {
            InitLogging();

            _config = config;
            _credentials = config.TelegramSettings.TgCredentials;
            _messageProcessor = messageProcessor;
            _client = new WTelegram.Client(Config);
        }

        private void InitLogging()
        {
            WTelegram.Helpers.Log = (level, logStr) =>
            {
                if (logStr.Contains("RpcError 420 FLOOD_WAIT_3"))
                    return;

                if (level == (int)LogLevel.Error)
                    NLog.LogManager.GetCurrentClassLogger().Error(logStr);
                else if (level == (int)LogLevel.Critical)
                    NLog.LogManager.GetCurrentClassLogger().Fatal("фатально " + logStr);

                CheckFatalError(level, logStr);
            };
        }

        private void CheckFatalError(int level, string logStr)
        {
            if (level == (int)LogLevel.Critical && logStr.Contains("SocketException TimedOut (10060):"))
            {
                _messageProcessor.ClearAll();
                Start();
            }

        }

        public async Task Start()
        {
            var my = await _client.LoginUserIfNeeded();

            //_client.OnUpdate += Client_OnUpdate;

            var startDate = new DateTime(2023, 1, 1);
            var finihsDate = new DateTime(2023, 3, 3);

            var currentDate = finihsDate;
            while (currentDate > startDate)
            {
                var localFinishDate = currentDate;
                currentDate = currentDate.AddDays(-3);
                await AddOldMessages(1210302841, 0, currentDate, localFinishDate);
            }
        }

        private async Task Client_OnUpdate(IObject arg)
        {
            try
            {
                if (arg is not UpdatesBase updates)
                    return;

                updates.CollectUsersChats(Users, Chats);
                foreach (var update in updates.UpdateList)

                    switch (update)
                    {
                        case UpdateNewMessage unm: 
                                if(unm.message.From?.ID == 176280269)
                            {

                            }

                            if(unm is TL.UpdateNewChannelMessage || unm is TL.MessageMediaWebPage || unm.message.Peer.ID != 176280269)
                            {

                            }
                            else
                                await ProcessMessageAsync(unm.message); 
                            break;
                        //case UpdateEditMessage uem: DisplayMessage(uem.message, true); break;
                        //case UpdateDeleteChannelMessages udcm: Console.WriteLine($"{udcm.messages.Length} message(s) deleted in {Chat(udcm.channel_id)}"); break;
                        //case UpdateDeleteMessages udm: Console.WriteLine($"{udm.messages.Length} message(s) deleted"); break;
                        //case UpdateUserTyping uut: Console.WriteLine($"{User(uut.user_id)} is {uut.action}"); break;
                        //case UpdateChatUserTyping ucut: Console.WriteLine($"{Peer(ucut.from_id)} is {ucut.action} in {Chat(ucut.chat_id)}"); break;
                        //case UpdateChannelUserTyping ucut2: Console.WriteLine($"{Peer(ucut2.from_id)} is {ucut2.action} in {Chat(ucut2.channel_id)}"); break;
                        //case UpdateChatParticipants { participants: ChatParticipants cp }: Console.WriteLine($"{cp.participants.Length} participants in {Chat(cp.chat_id)}"); break;
                        //case UpdateUserStatus uus: Console.WriteLine($"{User(uus.user_id)} is now {uus.status.GetType().Name[10..]}"); break;
                        //case UpdateUserName uun: Console.WriteLine($"{User(uun.user_id)} has changed profile name: @{uun.username} {uun.first_name} {uun.last_name}"); break;
                        //case UpdateUserPhoto uup: Console.WriteLine($"{User(uup.user_id)} has changed profile photo"); break;
                        default: Console.WriteLine(update.GetType().Name); break; // there are much more update types than the above cases
                    }
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }
        }

        public async Task AddOldMessages(long channelId, int count, DateTime startDateTime, DateTime? finishDateTime)
        {
            var chats = await _client.Messages_GetAllChats();
            InputPeer peer = chats.chats[channelId]; // the chat we want
            IEnumerable<MessageBase> messages = null;
            if (count == 0)
            {
                var finishDate = finishDateTime?? DateTime.Now;
                var history1 = await _client.Messages_GetHistory(peer, 
                    limit: 100 * (int)(DateTime.UtcNow - startDateTime).TotalDays,
                    offset_date: finishDate                    );

                messages = history1.Messages.Where(x => x.Date > startDateTime);

                if (messages.Count() == history1.Messages.Count())
                    Debug.Assert(false);
            }
            else
            {
                var res = await _client.Messages_GetHistory(peer, limit: count);
                messages = res.Messages;
            }

            var list = new List<ChannelPost>();
            foreach (var message in messages.Reverse())
            {
                list.Add(await ProcessBatchMessageAsync(message));
            }

            var combinedPosts = new List<ChannelPost>();
            var currentPost = list.First();
            for (int i = 1; i < list.Count; i++)
            {
                if (!TryToUpdateWithNewPost(currentPost, list[i]))
                {
                    AddFileToDb(currentPost);
                    currentPost = list[i];
                }
            }
        }


        private bool AddFileToDb(ChannelPost message)
        {
            var audio = message.Attaches.Where(x => x.Type == AttachType.Audio);
            var image = message.Attaches.FirstOrDefault(x => x.Type == AttachType.Photo);

            if (!audio.Any())
                return false;

            if(message.Text.Contains("Колобок"))
                return false;

            var optionsBuilder = new DbContextOptionsBuilder<VideoCatalogDbContext>();
            optionsBuilder.UseSqlServer("Server=localhost;Database=FileStore;Encrypt=False;Trusted_Connection=True;");

            var db1 = new VideoCatalogDbContext(optionsBuilder.Options);

            try
            {
                using (var manager = new DbUpdateManager(db1))
                {
                    manager.AddAudioFilesFromTg(message.Text, audio.Select(x => x.FilePath),
                        FileStore.Domain.Models.AudioType.FairyTale, FileStore.Domain.Models.Origin.Soviet, image.FilePath);
                }
            }
            catch (Exception)
            {
            }

            return true;
        }

            internal bool TryToUpdateWithNewPost(ChannelPost original, ChannelPost channelPost)
        {
            if (channelPost.Text.Length > 50)
                return false;

            original.Attaches.AddRange(channelPost.Attaches);
            if (string.IsNullOrEmpty(original.Text) && !string.IsNullOrEmpty(channelPost.Text))
                original.Text = channelPost.Text;

            return true;
        }

        private async Task<ChannelPost> ProcessBatchMessageAsync(MessageBase messageBase)
        {
            var fromId = (int)messageBase.Peer.ID;
            switch (messageBase)
            {
                case Message message:

                    _messageProcessor.UpdateMessage(fromId, _GetMessageGroupId(message));

                    return await GetPostFromMessage(message);
            }

            return null;
        }

        private async Task ProcessMessageAsync(MessageBase messageBase)
        {
            var fromId = (int)messageBase.Peer.ID;
            switch (messageBase)
            {
                case Message message:

                    _messageProcessor.UpdateMessage(fromId, _GetMessageGroupId(message));

                    var channelPost = await GetPostFromMessage(message);

                    _messageProcessor.ProcessMessage(fromId, channelPost);
                    break;
            }
        }

        private async Task<ChannelPost> GetPostFromMessage(Message message)
        {
            var channelPost = new ChannelPost(message);

            channelPost.Text = ConvertText(message);
            if (string.IsNullOrEmpty(channelPost.Text) && !string.IsNullOrWhiteSpace(message.message))
                return null;

            var messageGroupId = _GetMessageGroupId(message);

            channelPost.MessageGroupId = messageGroupId;
            channelPost.Date = message.Date;
            channelPost.ChannelName = Peer(message.Peer);
            channelPost.SourceChannelName = Peer(message.fwd_from?.from_id);
            channelPost.Id = message.ID;

            await AddAttaches(message, channelPost);

            return channelPost;
        }

        private static long _GetMessageGroupId(Message message)
        {
            if (message == null)
                return 0;

            return message.grouped_id != 0 ? message.grouped_id : -message.id;
        }

        private string ConvertText(Message messageBase)
        {
            var message = messageBase.message.Trim();

            if (string.IsNullOrEmpty(message))
                return message;

            return message.Trim();
        }

        private async Task AddAttaches(Message message, ChannelPost internalChannelPost)
        {
            if (message.media == null)
                return;

            var downloadPath = Path.Combine(_config.RootDownloadFolder, TELEGRAM_DOWNLOAD_FOLDER);
            var attach = new Attach(message.peer_id, downloadPath);

            var policy = Policy
                .Handle<Exception>()
                .WaitAndRetryAsync(3, retryAttempt => TimeSpan.FromSeconds(1));

            try
            {
                await policy.ExecuteAsync(async () => await DownloadAttachNow(message, internalChannelPost, attach));
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex, $"Проблема с сохранением аттача {internalChannelPost.PostLink} {message.media}");
            }
        }

        // Download attach without waiting
        private async Task DownloadAttachNow(Message message, ChannelPost internalChannelPost, Attach attach)
        {
            var goodAttach = await DownloadAttach(message, attach, internalChannelPost);

            if (goodAttach)
                internalChannelPost.Attaches.Add(attach);
        }

        private async Task<bool> DownloadAttach(Message message, Attach attach, ChannelPost internalChannelPost)
        {
            var result = false;
            try
            {
                attach.IsLoading = true;

                switch (message.media)
                {
                    case MessageMediaPhoto { photo: Photo photo }:
                        attach.SetPhotoPath(photo);
                        using (var fileStream = File.Create(attach.FilePath))
                        {
                            var type = await _client.DownloadFileAsync(photo, fileStream);
                        }
                        result = true;
                        break;
                    case MessageMediaDocument { document: Document document }:
                        attach.SetDocumentPath(document);

                        if (!attach.FilePath.EndsWith(".mp3"))
                            return false;

                        using (var fileStream = File.Create(attach.FilePath))
                        {
                            var type = await _client.DownloadFileAsync(document, fileStream);
                        }
                        result = true;
                        break;
                    case MessageMediaWebPage page:
                        break;
                    case MessageMediaVenue venue:
                        // это место проведения мероприятия
                        break;
                    case MessageMediaContact contact:
                        // это контакт
                        break;
                    case MessageMediaGame game:
                        // это игра
                        break;
                    case MessageMediaGeoLive empty:
                    case MessageMediaGeo geo:
                        // это геолокация
                        break;
                    case MessageMediaPoll poll:
                        // это геолокация
                        break;
                    case MessageMediaInvoice invoice:
                        // это деньги
                        break;
                    case MessageMediaUnsupported unsupported:
                        // TLSharp не понял, что это такое
                        break;
                    case MessageMediaDice empty:
                        // пусто
                        break;
                    default:
                        throw new NotSupportedException($"Проблема с типом {message.media.GetType()} {message.media.GetType() == typeof(MessageMediaWebPage)}");
                }
            }
            catch (Exception ex)
            {
                throw;
            }
            finally
            {
                attach.IsLoading = false;
            }

            return result;
        }

        string Config(string what)
        {
            switch (what)
            {
                case "api_id": return _credentials.AppId.ToString();
                case "api_hash": return _credentials.AppHash.ToString();
                case "phone_number": return _credentials.Login;
                case "verification_code":
                    {
                        Console.Write("Code: ");
                        return "66431";
                    }
                case "first_name": return "John";      // if sign-up is required
                case "last_name": return "Doe";        // if sign-up is required
                case "password": return _credentials.Password;     // if user has enabled 2FA
                default: return null;                  // let WTelegramClient decide the default config
            }
        }

        private readonly AppConfig _config;
        private readonly TgCredentials _credentials;
        private readonly IMessageProcessor _messageProcessor;
        private readonly Client _client;
        static readonly Dictionary<long, User> Users = new();
        static readonly Dictionary<long, ChatBase> Chats = new();
        private readonly string TELEGRAM_DOWNLOAD_FOLDER = "Telegram";

        private static string User(long id) => Users.TryGetValue(id, out var user) ? user.ToString() : $"User {id}";
        private static string Chat(Peer peer)
        {
            if (Chats.TryGetValue(peer.ID, out var chat))
                return chat.Title;
            return peer.ID.ToString();
            //else
            //{
            //    var chatInfo = (await _client.Channels_GetFullChannel(peer.));
            //    return chatInfo
            //}
        }
        private static string Peer(Peer peer) => peer is null ? null : peer is PeerUser user ? User(user.user_id)
            : peer is PeerChat or PeerChannel ? Chat(peer) : $"Peer {peer.ID}";

    }
}
