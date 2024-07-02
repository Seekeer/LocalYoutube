using API.FilmDownload;
using FileStore.Domain;
using FileStore.Domain.Models;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Services;
using Google.Apis.Util.Store;
using Google.Apis.YouTube.v3;
using Google.Apis.YouTube.v3.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;
using Quartz;
using System;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

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

        public CheckYoutubePlaylistJob(UserManager<ApplicationUser> userManager, TgBot bot,
            IServiceScopeFactory serviceScopeFactory , AppConfig appConfig) 
        {
            _scopeFactory = serviceScopeFactory;
            _appConfig = appConfig;
            _userManager = userManager;
            _bot = bot;
        }

        protected override async Task Execute()
        {
            var user  = await _userManager.FindByNameAsync("dim");

            await CheckVideoByUser(user);
        }

        private async Task CheckVideoByUser(ApplicationUser user)
        {
            YouTubeService youtubeService = GetYoutubeService(user);

            //var channelsListRequest = youtubeService.Channels.List("contentDetails");
            //channelsListRequest.Mine = true;

            //// Retrieve the contentDetails part of the channel resource for the authenticated user's channel.
            //var channelsListResponse = await channelsListRequest.ExecuteAsync();

            PlaylistItemListResponse playlistResponse = await GetLocalTubePlayListVideos(youtubeService);
            foreach (var item in playlistResponse.Items)
            {
                var videoLink = $"https://www.youtube.com/watch?v={item.ContentDetails.VideoId}";
                var coverUrl = $"https://i.ytimg.com/vi/{item.ContentDetails.VideoId}/maxresdefault.jpg";

                var youtubeDownloader = new YoutubeDownloader(_appConfig);
                await youtubeDownloader.DownloadAndProcess(new DownloadTask(videoLink, coverUrl), _scopeFactory, 
                    ex => 
                    { 
                    },
                    async file =>
                    {
                        await youtubeService.PlaylistItems.Delete(item.Id).ExecuteAsync();
                        await _bot.NotifyDownloadEnded(user.TgId, file);
                    });
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
