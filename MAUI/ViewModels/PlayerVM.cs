using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using MAUI.Pages;
using MAUI.Services;
using System.Collections.ObjectModel;
using System.Timers;
using FileStore.Domain.Dtos;
using MAUI.Downloading;
using CommunityToolkit.Maui.Views;
using Infrastructure;
using System.Text.RegularExpressions;
using System.Linq;
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using System.Diagnostics;
using Xabe.FFmpeg;
using FileStore.Domain.Models;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Maui.Dispatching;

namespace MAUI.ViewModels
{
    public partial class PlayerVM : VMBase<VideoFileResultDtoDownloaded>
    {
        private readonly IAPIService _api;
        private readonly IMAUIService _mauiDBService;
        private readonly DownloadManager _downloadManager;
        private readonly INavigationService _navigationService;
        private readonly IDispatcher _dispatcher;
        [ObservableProperty]
        private VideoFileResultDtoDownloaded _file;

        [ObservableProperty]
        private SeekPositionCollectionVM _seekPositionCollection = new SeekPositionCollectionVM();

        [ObservableProperty]
        private string _videoUrl;

        [ObservableProperty]
        private string _coverUrl;

        [ObservableProperty]
        private MediaSource _videoSource;

        [ObservableProperty]
        private TimeSpan _position;

        [ObservableProperty]
        private IEnumerable<VideoDescriptionRowVM> _description;

        [ObservableProperty]
        private BookmarksVM _bookmarks;
        private double _lastPosition;
        private bool _pausedCalled;
        private System.Timers.Timer _positionTimer;

        private HubConnection _hubConnection;

        public Player Page { get; internal set; }

        public PlayerVM(IAPIService api, IMAUIService positionRepository, DownloadManager downloadManager, IDispatcher dispatcher,
            INavigationService navigationService)
        {
            _api = api;
            _mauiDBService = positionRepository;
            _downloadManager = downloadManager;
            _navigationService = navigationService;
            _dtoAssign = AssignDTO;
            _dispatcher = dispatcher;

            InitSignalR();
            (App.Current as App).CurrentPlayerVM = this;
        }

        private void InitSignalR()
        {
            _hubConnection = new HubConnectionBuilder()
                .WithUrl($@"{HttpClientAuth.BASE_SERVER_URL}/player", options =>
                {
                    options.AccessTokenProvider = () => _api.GetAccessToken();
                })
                .Build();
            _hubConnection.StartAsync();
            _hubConnection.On<string, string>("Connected", (connectionId, userId) =>
            {
                Console.Write($"User: {userId} connected as {connectionId}");
                _clientsDict.Add(new(connectionId, userId));
                UpdateClients();
            });
            _hubConnection.On<string, string>("Disconnected", (connectionId, userId) =>
            {
                Console.Write($"User: {userId} connected as {connectionId}");
                if(_clientsDict.Any(x => x.Key == connectionId))
                {
                    var item = _clientsDict.First(x => x.Key == connectionId);
                    _clientsDict.Remove(item);
                    UpdateClients();
                }
            });
            _hubConnection.On<int, TimeSpan>("PlayOnClient", async (videoId, position) =>
            {
                var dto = new VideoFileResultDtoDownloaded
                {
                    IsServerRequest = true,
                    Id = videoId
                };
                AssignDTO(dto);
                await Page.SetPositionAsync(position);
                //_dispatcher.Dispatch(() => 

                ////MainThread.BeginInvokeOnMainThread(() =>
                //{
                //    Task.Run(async () =>
                //    {
                //        await _navigationService.NavigateToPlayer();
                //    }).Wait();
                //    // Code to run on the main thread
                //});
            });
        }
        [ObservableProperty]
        private bool _haveClients;
        [ObservableProperty]
        private List<KeyValuePair<string, string>> _clientsDict = new();
        public KeyValuePair<string, string> SelectedClient
        {
            set
            {
                _hubConnection.SendAsync("Play", value.Key, this.File.Id, Page.GetMedia().Position);
            }
        }

        // Need cause have problems with ObservCollection
        private void UpdateClients()
        {
            ClientsDict = new (_clientsDict);
            HaveClients = ClientsDict.Count > 0;
        }

        [ObservableProperty]
        private IEnumerable<Playlist> _playlists;

        public Playlist SelectedPlaylist
        {
            set { if (value != null) _api.AddToPlaylists(File.Id, value.Id); }
        }

        [RelayCommand]
        public async Task AddPlaylist()
        {
            string playlistName = await App.Current.MainPage.DisplayPromptAsync("Создать плейлист", "Введите название");
            if (string.IsNullOrEmpty(playlistName))
                return;

            await _api.AddPlaylistAsync(playlistName);
            Playlists = await _api.GetPlaylistsAsync();
        }

        public void Dispose()
        {
            _positionTimer?.Dispose();
            _hubConnection.StopAsync();
        }

        private void AssignDTO(VideoFileResultDtoDownloaded dto)
        {
            this.File = dto;
            this.VideoUrl = dto.IsDownloaded ?
                dto.Path :
                HttpClientAuth.GetVideoUrlById(dto.Id);
            Bookmarks = new BookmarksVM(_api, () => Page.GetMedia().Position, dto.Id);

            Description = VideoDescriptionRowVM.ParseDescription(dto.Description, true);

            Playlists = dto.Playlists;

            if(!dto.IsServerRequest)
                ProcessFile();
        }

        private async Task ProcessFile()
        {
            //var fileService = GetFileService();
            _mauiDBService.AddFileIfNeeded(File);

            //DownloadAndReplace();
        }

        public async Task InitMedia()
        {
            await UpdatePosition();
            StartPositionUpdateTimer();

            this.Page.GetMedia().StateChanged += PlayerVM_StateChanged;
        }

        private void PlayerVM_StateChanged(object? sender, CommunityToolkit.Maui.Core.Primitives.MediaStateChangedEventArgs e)
        {
            var state = Page.GetMedia().CurrentState;
            if (state == CommunityToolkit.Maui.Core.Primitives.MediaElementState.Paused)
            {
                //var state = Page.GetMedia().CurrentState;
                //if (!_pausedCalled)
                {
                    _pausedCalled = true;
                    Bookmarks.Paused();
                }
            }
            else if (_pausedCalled && state == CommunityToolkit.Maui.Core.Primitives.MediaElementState.Playing)
            {
                Bookmarks.Resumed();
                _pausedCalled = false;
            }
            else 
            {
                _pausedCalled = false;
            }
        }

        private async Task UpdatePosition()
        {
            // TODO async??
            //FileUserInfo localPosition = null;
            //var setLocalPositionTask = Task.Run(async () =>
            //{
            //    localPosition = await _mauiDBService.GetById(File.Id);
            //    if (localPosition != null)
            //        await Page.PlayerElement.SeekTo(TimeSpan.FromSeconds(localPosition.Position));
            //});
            //var remotePositionTask = _api.GetPositionAsync(File.Id);
            //var remotePosition = await setLocalPositionTask.ContinueWith(async x => await remotePositionTask);

            double? position = _mauiDBService.GetInfoById(File.Id)?.Position;

            try
            {
                // Try to get remote position - if it is newer - set to it.
                var remotePosition = await _api.GetPositionAsync(File.Id);
                if(remotePosition != null)
                {
                    if (await _mauiDBService.SetPositionAsync(File.Id, remotePosition))
                        position = remotePosition.Position;
                }
            }
            catch (Exception ex)
            {
            }

            if (position != null)
                await Page.SetPositionAsync(TimeSpan.FromSeconds(position.Value));
        }

        private IMAUIService GetFileService()
        {
            return Application.Current.MainPage.Handler.MauiContext.Services.GetService<IMAUIService>();
        }

        private void StartPositionUpdateTimer()
        {
            _positionTimer = new System.Timers.Timer();
            _positionTimer.Elapsed += new ElapsedEventHandler(async (_, __) =>
            {
                await UpdatePositionByControl();
            });
            _positionTimer.Interval = 500;
            _positionTimer.Enabled = true;
        }

        public async Task UpdatePositionByControl()
        {
            try
            {
                var position = Page.GetMedia().Position.TotalSeconds;
                if (position < 3)
                    return;

                var positionDTO = new PositionDTO { Position = position };
                //using var fileService = GetFileService();
                await _mauiDBService.SetPositionAsync(File.Id, positionDTO);
                await _api.SetPositionAsync(File.Id, positionDTO);
                Trace.WriteLine($"Position : {position}");

                if (SeekPositionCollection.PositionUpdated(Page.GetMedia().Position))
                    ShowSnackWithNavigation();

                //if (_lastPosition == position)
                //{
                //    var state = Page.GetMedia().CurrentState;
                //    if (!_pausedCalled)
                //    {
                //        _pausedCalled = true;
                //        Bookmarks.Paused();
                //    }
                //}
                //else if (_pausedCalled)
                //{
                //    await Bookmarks.Resumed();
                //    _pausedCalled = false;
                //}

                //_lastPosition = position;
            }
            catch (Exception ex)
            {
            }
        }

        private void ShowSnackWithNavigation()
        {
            var snackbarOptions = new SnackbarOptions
            {
                ActionButtonTextColor = Colors.Purple,
                CornerRadius = new CornerRadius(10),
            };

            string text = $"Вы переместились";
            string actionButtonText = $"Вернуться обратно на {SeekPositionCollection.Positions.First().OriginalPositionStr}";
            Action action = async () => await Page.SetPositionAsync(SeekPositionCollection.Positions.First().OriginalPosition);
            TimeSpan duration = TimeSpan.FromSeconds(3);

            if(DeviceInfo.Current.Platform == DevicePlatform.Android)
                Snackbar.Make(text, action, actionButtonText, duration, snackbarOptions).Show();
        }

        [RelayCommand]
        public async Task Download()
        {
            await _downloadManager.StartDownloadAsync(File);
            Toast.Make($"Загрузка началась", ToastDuration.Short, 20).Show();
        }

        [RelayCommand]
        public async Task FullScreen()
        {
        }

        [RelayCommand]
        public async Task Refresh()
        {
            await _navigationService.GoBack();
            await _navigationService.NavigateAsync(nameof(Player), File);
        }

        [RelayCommand]
        public async Task NextDescriptionTimestamp()
        {
            var closestTime = VideoDescriptionRowVM.CalculateClosest(Page.GetMedia().Position, Description);

            Page.SetPositionAsync(closestTime);
        }

        [RelayCommand]
        public async Task AddBookmark()
        {
            await Bookmarks.AddMarkAsync(Page.GetMedia().Position);
        }

        [RelayCommand]
        public async Task Delete()
        {
            const string delete = "Удалить";
            const string replayMessage = "Начать с начала";
            const string deleteEverywhere = "Удалить отовсюду";
            string action = await Page.DisplayActionSheet("Удалить это видео с сервиса?", "Отмена", null, delete, replayMessage, deleteEverywhere);

            switch (action)
            {
                case deleteEverywhere:
                    await _api.DeleteVideoAsync(File.Id);
                    await _downloadManager.DeleteDownloaded(File.Id);
                    await _navigationService.GoBack();
                    break;
                case delete:
                    await _api.DeleteVideoAsync(File.Id);
                    await _navigationService.GoBack();
                    break;
                case replayMessage:
                    await Page.SetPositionAsync(TimeSpan.FromMilliseconds(1));
                    Page.GetMedia().Play();
                    break;
                default:
                    break;
            }
        }

        internal async Task NavigateToSeason()
        {
            var dtos = await _api.GetFilesForSeason(File.SeasonId);
            if(dtos.Any())
                await _navigationService.NavigateAsync(nameof(ListPage), dtos);
        }
    }

}