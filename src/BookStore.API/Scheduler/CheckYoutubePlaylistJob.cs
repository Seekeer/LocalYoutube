using API.FilmDownload;
using FileStore.Domain;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using FileStore.Infrastructure.Repositories;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Services;
using Google.Apis.Util.Store;
using Google.Apis.YouTube.v3;
using Google.Apis.YouTube.v3.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;
using Quartz;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using VkNet.Model;

namespace Infrastructure.Scheduler
{
    [DisallowConcurrentExecution]
    public class CheckYoutubePlaylistJob : JobBase
    {
        private const string PLAYLIST_NAME = "LocalTube";
        private const string ApplicationName = "Youtube API .NET Quickstart";
        static string[] Scopes = { YouTubeService.Scope.Youtube };
        private static string _playlistId;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly AppConfig _appConfig;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly TgBot _bot;
        private readonly IExternalVideoMappingsRepository _externalVideoRepository;
        private readonly IExternalVideoMappingsService _externalVideoService;

        public CheckYoutubePlaylistJob(UserManager<ApplicationUser> userManager, TgBot bot,
            IServiceScopeFactory serviceScopeFactory, AppConfig appConfig,
            IExternalVideoMappingsRepository externalVideoRepository, IExternalVideoMappingsService externalVideoService) 
        {
            _scopeFactory = serviceScopeFactory;
            _appConfig = appConfig;
            _userManager = userManager;
            _bot = bot;
            _externalVideoRepository = externalVideoRepository;
            _externalVideoService = externalVideoService;
        }

        protected override async Task Execute()
        {
            var user = await _userManager.FindByNameAsync("dim");

            YouTubeService youtubeService = GetYoutubeService(user);

            // Track New channels
            //await FillChanelsMapping(youtubeService);

            await CheckChannelsUpdates(youtubeService);

            PlaylistItemListResponse playlistResponse = await GetLocalTubePlayListVideos(youtubeService);
            foreach (var item in playlistResponse.Items)
            {
                if (await this.DownloadVideo(user, youtubeService, item.ContentDetails.VideoId, false))
                    await youtubeService.PlaylistItems.Delete(item.Id).ExecuteAsync();
            }
        }

        private async Task<bool> DownloadVideo(ApplicationUser user, YouTubeService youtubeService, string videoId, bool isAuto)
        {
            var videoLink = $"https://www.youtube.com/watch?v={videoId}";
            var coverUrl = $"https://i.ytimg.com/vi/{videoId}/maxresdefault.jpg";

            var youtubeDownloader = new YoutubeDownloader(_appConfig);

            var result = false;
            await youtubeDownloader.DownloadAndProcess(new DownloadTask(videoLink, coverUrl) { IsAutoTask = isAuto }, _scopeFactory,
                async ex =>
                {
                    await _bot.NotifyDownloadProblem(user.TgId, videoLink);
                },
                async file =>
                {
                    result = true;
                    await _bot.NotifyDownloadEnded(user.TgId, file);
                });

            return result;
        }

        private async Task FillChanelsMapping(YouTubeService youtubeService)
        {
            var req = youtubeService.Subscriptions.List(new Google.Apis.Util.Repeatable<string>(["id", "contentDetails", "snippet"]));
            req.Mine = true;
            req.MaxResults = 50;
            var subscriptions = await req.ExecuteAsync();

            var channelInfos = subscriptions.Items.Select(subscription =>
                new ChannelInfo { ChannelId = subscription.Snippet.ResourceId.ChannelId, ChannelName = subscription.Snippet.Title });
            await _externalVideoService.AddExternalSourceMapping(channelInfos, DownloadType.Youtube);
        }

        private async Task CheckChannelsUpdates(YouTubeService youtubeService)
        {
            var list = new List<string>();
            IEnumerable<ExternalVideoSourceMapping> records =
                (await _externalVideoRepository.SearchAsync(x => x.Network == DownloadType.Youtube &&
                // Check only once in 6 hours to not over YT limits.
                    x.LastCheckDate < DateTime.UtcNow.AddHours(-6) &&
                    x.CheckNewVideo
                )).ToList();

            NLog.LogManager.GetCurrentClassLogger().Info($"Start CheckChannelsUpdates");

            //records = records.Where(x => x.Id == 3);
            var user = await _userManager.FindByNameAsync("dim");

            foreach (var subscription in records)
            {
                var videoRequest = youtubeService.Search.List(new string[] { "snippet", "id" });
                videoRequest.ChannelId = subscription.ChannelId;
                videoRequest.Order = SearchResource.ListRequest.OrderEnum.Date;
                videoRequest.MaxResults = 50;
                videoRequest.PublishedAfterDateTimeOffset = new DateTimeOffset(subscription.LastCheckDate.AddDays(-0.5));
                var response = (await videoRequest.ExecuteAsync());
                var videos = response.Items.ToList();
                //videos.Clear();
                while(response.NextPageToken != null)
                {
                    videoRequest.PageToken = response.NextPageToken;
                    response = (await videoRequest.ExecuteAsync());
                    videos.AddRange(response.Items);
                }

                NLog.LogManager.GetCurrentClassLogger().Info($"Channel {subscription.ChannelName} {videos.Count} videos");

                videos.Reverse();
                foreach (var video in videos)
                {
                    if (video.Id.Kind == "youtube#video"
                        && video.Snippet.Title?.Contains("#") == false && video.Snippet.Title?.Contains("@") == false)
                        await DownloadVideo(user, youtubeService, video.Id.VideoId, true);
                    else
                        NLog.LogManager.GetCurrentClassLogger().Info($"Havent downloaded. Kind: {video.Id.Kind}, title: {video.Snippet.Title}, id: {video.Id.VideoId}");
                }

                subscription.LastCheckDate = DateTime.UtcNow;
                await _externalVideoRepository.UpdateAsync(subscription);
            }
        }

        private static async Task<PlaylistItemListResponse> GetLocalTubePlayListVideos(YouTubeService youtubeService)
        {
            if (string.IsNullOrEmpty(_playlistId))
            {
                var searchListRequest = youtubeService.Playlists.List("snippet,contentDetails");
                searchListRequest.Mine = true;

                var searchListResponse = await searchListRequest.ExecuteAsync();
                var localTube = searchListResponse.Items.FirstOrDefault(x => x.Snippet.Title.Equals(PLAYLIST_NAME, System.StringComparison.OrdinalIgnoreCase));
                _playlistId = localTube.Id;
            }

            var localTubePlayList = youtubeService.PlaylistItems.List("snippet,contentDetails");
            localTubePlayList.PlaylistId = _playlistId;

            var response = await localTubePlayList.ExecuteAsync();
            return response;
        }

        private YouTubeService GetYoutubeService(ApplicationUser user)
        {
            // TODO - get store from user.

            UserCredential credential;
            using (var stream = new FileStream("credentials.json", FileMode.Open, FileAccess.Read))
            {
                // The file token.json stores the user's access and refresh tokens, and is created
                // automatically when the authorization flow completes for the first time.
                string credPath = "token.json";
                credential = GoogleWebAuthorizationBroker.AuthorizeAsync(
                    GoogleClientSecrets.Load(stream).Secrets,
                    Scopes,
                    "user",
                    CancellationToken.None,
                    new FileDataStore(credPath, true)).Result;
            }

            var youtubeService = new YouTubeService(new BaseClientService.Initializer()
            {
                HttpClientInitializer = credential,
                ApplicationName = this.GetType().ToString()
            });
            return youtubeService;
        }
    }
}
