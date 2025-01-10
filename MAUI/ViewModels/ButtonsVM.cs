using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using FileStore.Domain.Dtos;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using MAUI.Downloading;
using MAUI.Pages;
using MAUI.Services;
using Shiny.NET;
using System.Collections.ObjectModel;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace MAUI.ViewModels
{
    public class VideoFileResultDtoDownloaded : VideoFileResultDto
    {
        public bool IsDownloaded { get; set; }
        public bool IsServerRequest { get; set; }
        public string Path { get; set; }
        public int SeasonId { get;  set; }
        public IEnumerable<Playlist> Playlists { get; internal set; }

        public Playlist SelectedPlaylist
        {
            set { if(value != null) APIService.AddToPlaylists(Id, value.Id); }
        }

        public IAPIService APIService { get; internal set; }
    }

    public partial class ButtonsVM : VMBase<string>
    {
        private readonly IAPIService _api;
        private readonly INavigationService _navigationService;
        private readonly LocalFilesRepo _videoFileRepository;
        private readonly DownloadManager _downloadManager;

        public ButtonsVM(IAPIService api, INavigationService navigationService, LocalFilesRepo localFileRepository, DownloadManager downloadManager) {
            _api = api;
            _navigationService = navigationService;
            _videoFileRepository = localFileRepository;
            _downloadManager = downloadManager;

            Connectivity.ConnectivityChanged += (_, __) =>
            {
                OnPropertyChanged(nameof(InternetEnabled));
                OnPropertyChanged(nameof(InternetDisabled));
            };
        }

        public bool InternetEnabled
        {
            get
            {
#if DEBUG
                return true;
#endif
                return Connectivity.NetworkAccess == NetworkAccess.Internet;
            }
        }

        public bool InternetDisabled
        {
            get
            {
                return Connectivity.NetworkAccess != NetworkAccess.Internet;
            }
        }

        [RelayCommand(CanExecute = nameof(InternetEnabled))]
        public async Task ShowHistory()
        {
            IsBusy = true;
            var dtos = await _api.GetLatestAsync(count: 10);

            await _navigationService.NavigateAsync(nameof(ListPage), dtos);
        }

        [RelayCommand]
        public async Task ShowDownloaded()
        {
            var dtos = await _videoFileRepository.GetFiles();
            await _navigationService.NavigateAsync(nameof(ListPage), dtos);
        }


        [RelayCommand]
        public async Task ShowLatestVideo()
        {
            IsBusy = true;

            var dtos = await _api.GetLatestAsync(count: 1);
            if(dtos.Any())
                await _navigationService.NavigateAsync(nameof(Player), dtos.First());
        }

        [RelayCommand(CanExecute = nameof(InternetEnabled))]
        public async Task ShowDownloading()
        {
            await _navigationService.NavigateAsync(nameof(MainPage), "");
        }

        [RelayCommand(CanExecute = nameof(InternetEnabled))]
        public async Task ShowFresh()
        {
            IsBusy = true;
            var dto = await _api.GetFreshAsync();
            await _navigationService.NavigateAsync(nameof(FreshPage), dto);
        }

        //[RelayCommand(CanExecute = nameof(InternetEnabled))]
        [RelayCommand]
        public async Task ShowSeries()
        {
            var dtos = await _videoFileRepository.GetFiles();
            await _navigationService.NavigateAsync(nameof(SeriesPage), dtos);
        }

        [RelayCommand]
        public async Task Logout()
        {
            var files = await _videoFileRepository.GetFiles();
            foreach (var file in files)
                await _downloadManager.DeleteDownloaded(file.Id);

            await _api.LogoutAsync();
        }

    }
}
