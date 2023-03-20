using FileStore.API;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Timers;
using System;
using FileStore.Domain.Interfaces;
using System.Linq;
using System.IO;
using Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using FileStore.Infrastructure.Context;
using Microsoft.EntityFrameworkCore;

namespace API.TG
{
    public interface IMessageProcessor
    {
        MessageProcessResult ProcessMessage(int linkId, ChannelPost channelPost);
        void UpdateMessage(int linkId, long groupId);
        void ClearAll();

        IServiceProvider Provider { get; }
    }

    public enum MessageProcessResult
    {
        Created,
        Updated,
        Ignored
    }

    public class MessageProcessor : IMessageProcessor
    {
        public MessageProcessor(AppConfig config, IServiceProvider provider)
        {
            _settings = config.TelegramSettings.TgCredentials;

            Provider = provider;

            InitTimer(config.TelegramSettings.TgCredentials);
        }

        public IServiceProvider Provider { get; }

        private void InitTimer(TgCredentials settings)
        {
            _timer.Interval = (settings.WaitTimeForMessageCheck.TotalMilliseconds);
            _timer.Elapsed += new ElapsedEventHandler(_timer_Elapsed);
            _timer.Enabled = true;
        }

        public void UpdateMessage(int linkId, long groupId)
            {
                if (_linksDict.ContainsKey(linkId))
                    _linksDict[linkId].UpdateMessage(groupId);
            }

            public MessageProcessResult ProcessMessage(int linkId, ChannelPost channelPost)
            {
                if (!_linksDict.ContainsKey(linkId))
                    _linksDict.Add(linkId, new AccountMessagesDictionary(linkId, _settings, Provider));

                var linkDictionary = _linksDict[linkId];
                return linkDictionary.ProcessMessage(channelPost.MessageGroupId, channelPost);
            }

            private void _timer_Elapsed(object sender, ElapsedEventArgs e)
            {
                CheckDictionary();
            }

            private void CheckDictionary()
            {
                lock (_locker)
                {
                    foreach (var link in _linksDict.ToList())
                    {
                        link.Value.CheckDictionary();
                    }
                }
            }

            public void ManualPost(int linkId, long postId)
            {
                var key = _linksDict.Keys.FirstOrDefault(x => x == linkId);

                _linksDict[key].PublishMessage(postId);
            }

            public void ClearAll()
            {
                _linksDict.Clear();
            }

        private readonly TgCredentials _settings;
        private object _locker = new();
        private readonly Dictionary<int, AccountMessagesDictionary> _linksDict = new Dictionary<int, AccountMessagesDictionary>();
        private readonly System.Timers.Timer _timer = new System.Timers.Timer();
    }

    public class AccountMessagesDictionary
    {
        public AccountMessagesDictionary(int linkId, TgCredentials telegramSettings, IServiceProvider provider)
        {
            this._provider = provider;
            this._settings = telegramSettings;
        }

        public void CheckDictionary()
        {
            try
            {
                if (!_messagesQueue.Any())
                    return;

                var oldestMessageGroup = _messagesQueue.Where(x => !x.Value.Message.Attaches.Any(attach => attach.IsLoading))
                    .ToArray().OrderBy(x => x.Value.Message.Id).FirstOrDefault().Value;

                if (oldestMessageGroup == null)
                    return;

                NLog.LogManager.GetCurrentClassLogger().Debug($"CheckDictionary oldestMessageGroup {oldestMessageGroup.Message.Id}");

                var timePassed = CalculateTime(oldestMessageGroup);
                if (timePassed < _settings.WaitForMediaTs)
                    return;

                var duplicate = FindDuplicate(oldestMessageGroup, _messagesQueue);
                if (duplicate != null)
                    oldestMessageGroup.Message.ForwardedPost = duplicate.Message;

                oldestMessageGroup.IsProcessed = Task.Run(() => AddFileToDb(oldestMessageGroup.Message)).Result;
                if (duplicate != null)
                    duplicate.IsProcessed = oldestMessageGroup.IsProcessed;

                _messagesQueue.ToList().ForEach(x =>
                {
                    if (x.Value.IsProcessed)
                        _messagesQueue.Remove(x.Key);
                });

            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }
        }

        private bool AddFileToDb(ChannelPost message)
        {
            var audio = message.Attaches.Where(x => x.Type == AttachType.Audio);
            var image = message.Attaches.FirstOrDefault(x => x.Type == AttachType.Photo);

            var optionsBuilder = new DbContextOptionsBuilder<VideoCatalogDbContext>();
            optionsBuilder.UseSqlServer("Server=localhost;Database=FileStore;Encrypt=False;Trusted_Connection=True;");

            var db1= new VideoCatalogDbContext(optionsBuilder.Options);

            //var db = _provider.GetRequiredService<VideoCatalogDbContext>();
            using (var manager = new DbUpdateManager(db1))
            {
                manager.AddAudioFilesFromTg(message.Text, audio.Select(x => x.FilePath),
                    FileStore.Domain.Models.AudioType.FairyTale, FileStore.Domain.Models.Origin.Soviet, image.FilePath);
            }

            return true;
        }

        private TimeSpan CalculateTime(TgMessageGroup oldestMessageGroup)
        {
            var passedTime = DateTime.UtcNow - oldestMessageGroup.LastUpdate;

            // DT TODO remove after testing
            // Wait for 5 sec in case if we have attach.
            if (oldestMessageGroup.Message.Attaches.Any())
                passedTime = passedTime.Add(TimeSpan.FromSeconds(-30));

            return passedTime;
        }

        internal MessageProcessResult ProcessMessage(long id, ChannelPost channelPost)
        {
            if (!_messagesQueue.ContainsKey(id))
            {
                var closeByTimePost = _messagesQueue.FirstOrDefault(x => TimeIsOk(x, channelPost)).Value;

                if(closeByTimePost == null)
                {
                    _messagesQueue.Add(id, new TgMessageGroup(channelPost));

                    return MessageProcessResult.Created;
                }

                if (closeByTimePost.TryToUpdateWithNewPost(channelPost))
                    return MessageProcessResult.Updated;
                else
                    return MessageProcessResult.Ignored;
            }
            else
            {
                var existingMessage = _messagesQueue[id];

                if (existingMessage.TryToUpdateWithNewPost(channelPost))
                    return MessageProcessResult.Updated;
                else
                    return MessageProcessResult.Ignored;
            }
        }

        private bool TimeIsOk(KeyValuePair<long, TgMessageGroup> x, ChannelPost channelPost)
        {
            var diff = x.Value.Message.Date - channelPost.Date;

            return diff.TotalMinutes < 1;
        }

        private TgMessageGroup FindDuplicate(TgMessageGroup oldestMessageGroup, Dictionary<long, TgMessageGroup> messagesQueue)
        {
            var nextMessage = messagesQueue.Select(x => x.Value).FirstOrDefault(x =>
                x.Message.Id == oldestMessageGroup.Message.Id + 1);


            if (nextMessage == null || !nextMessage.Message.IsForwarded() ||
                oldestMessageGroup.Message.Attaches.Any() ||
                !nextMessage.Message.Date.CompareDateTime(oldestMessageGroup.Message.Date, TimeSpan.FromSeconds(30)))
                return null;

            return nextMessage;
        }

        internal void PublishMessage(long postId)
        {
            _messagesQueue[postId].Message.Attaches.ForEach(x => x.IsLoading = false);
        }

        internal void UpdateMessage(long groupId)
        {
            // Wait for message to be downloaded
            if (_messagesQueue.ContainsKey(groupId))
                _messagesQueue[groupId].LastUpdate = DateTime.MaxValue;
        }

        private readonly Dictionary<long, TgMessageGroup> _messagesQueue = new Dictionary<long, TgMessageGroup>();

        private readonly IServiceProvider _provider;
        private readonly TgCredentials _settings;
    }

    internal static class DateTimeHelper
    {
        public static bool CompareDateTime(this DateTime date1, DateTime date2, TimeSpan possibleErrorRate)
        {
            return Math.Abs((date1 - date2).TotalMilliseconds) < possibleErrorRate.TotalMilliseconds;
        }
    }

    public class TgMessageGroup
    {
        public TgMessageGroup(ChannelPost channelPost)
        {
            Message = channelPost;

            _processedIds.Add(channelPost.Id);
        }

        public DateTime LastUpdate { get; set; } = DateTime.UtcNow;
        public ChannelPost Message { get; set; }
        public bool IsProcessed { get; set; }

        private List<int> _processedIds = new List<int>();

        internal bool TryToUpdateWithNewPost(ChannelPost channelPost)
        {
            if (_processedIds.Any(x => x == channelPost.Id))
                return false;

            Message.Attaches.AddRange(channelPost.Attaches);
            if (string.IsNullOrEmpty(Message.Text) && !string.IsNullOrEmpty(channelPost.Text))
                Message.Text = channelPost.Text;
            LastUpdate = DateTime.UtcNow;
            Message.Id = Math.Max(Message.Id, channelPost.Id);
            _processedIds.Add(channelPost.Id);
            return true;
        }
    }
}
