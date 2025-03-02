using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using FileStore.Domain.Models;
using MAUI.Downloading;
using MAUI.Pages;
using MAUI.Services;
using System.Collections.ObjectModel;
using System.Diagnostics;

namespace MAUI.ViewModels
{
    public partial class ListVM : VMBase<IEnumerable<VideoFileResultDtoDownloaded>>
    {
        public ListVM(INavigationService navigationService, DownloadManager downloadManager, IAPIService apiService)
        {
            _navigationService = navigationService;
            _downloadManager = downloadManager;
            this._apiService = apiService;

            DeviceDisplay.Current.MainDisplayInfoChanged += Current_MainDisplayInfoChanged;
            UpdateOrientation();

            _dtoAssign = async dto => 
            {
                dto = dto ?? new List<VideoFileResultDtoDownloaded>();

                GetPlaylistsAndCheckDownloadedInTheBackground(dto);

                var playlists = await _apiService.GetPlaylistsAsync();
                dto.ToList().ForEach(x =>
                    {
                        x.Playlists = playlists;
                    });
                this.Files = new ObservableCollection<VideoFileResultDtoDownloaded>(dto);
            };
        }

        private void GetPlaylistsAndCheckDownloadedInTheBackground(IEnumerable<VideoFileResultDtoDownloaded> dto)
        {
            Task.Run(async () => {
                await _downloadManager.CheckDownloadedAsync(dto);

                var playlists = await _apiService.GetPlaylistsAsync();
                dto.ToList().ForEach(x =>
                {
                    x.Playlists = playlists;
                });

            });
        }

        private void Current_MainDisplayInfoChanged(object? sender, DisplayInfoChangedEventArgs e)
        {
            UpdateOrientation();
        }

        private void UpdateOrientation()
        {
            IsVerticalOrientation = DeviceDisplay.Current.MainDisplayInfo.Orientation == DisplayOrientation.Portrait;
            IsPortraitOrientation = !IsVerticalOrientation;
        }

        [ObservableProperty]
        ObservableCollection<VideoFileResultDtoDownloaded> _files;

        public bool DisplayImages
        {
            get
            {
                return Connectivity.NetworkAccess == NetworkAccess.Internet;
            }
        }

        [ObservableProperty]
        bool _isVerticalOrientation;
        [ObservableProperty]
        bool _isPortraitOrientation;

        [RelayCommand]
        public async Task ItemTapped(VideoFileResultDtoDownloaded videoFileResultDto)
        {
            await _navigationService.NavigateAsync(nameof(Player), videoFileResultDto);
        }

        [RelayCommand]
        public async Task DownloadVideo(int id)
        {
            await _downloadManager.StartDownloadAsync(Files.First(x => x.Id == id));
        }

        [RelayCommand]
        public async Task DownloadTopVideo(string countStr)
        {
            var count = int.Parse(countStr);
            await _downloadManager.StartDownloadAsync(Files.Where(x => !x.IsDownloaded).Take(count));
        }

        [RelayCommand]
        public async Task AddPlaylist()
        {
            string playlistName = await App.Current.MainPage.DisplayPromptAsync("Создать плейлист", "Введите название");
            await _apiService.AddPlaylistAsync(playlistName);
            _dtoAssign(Files);
        }

        [RelayCommand]
        public async Task DeleteDownloadVideo(int id)
        {
            await _downloadManager.DeleteDownloaded(id);
        }

        [RelayCommand]
        public async Task DeleteVideoFromServer(int id)
        {
            await _apiService.DeleteVideoAsync(id);
        }

        private readonly INavigationService _navigationService;
        private readonly DownloadManager _downloadManager;
        private readonly IAPIService _apiService;
    }
}
