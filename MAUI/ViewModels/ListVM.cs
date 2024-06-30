using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using MAUI.Downloading;
using MAUI.Pages;
using MAUI.Services;
using System.Collections.ObjectModel;

namespace MAUI.ViewModels
{
    public partial class ListVM :  VMBase<IEnumerable<VideoFileResultDtoDownloaded>>
    {
        public ListVM(INavigationService navigationService, DownloadManager downloadManager)
        {
            _navigationService = navigationService;
            _downloadManager = downloadManager;

            DeviceDisplay.Current.MainDisplayInfoChanged += Current_MainDisplayInfoChanged;
            UpdateOrientation();

            _dtoAssign = dto =>
            {
                dto = dto ?? new List<VideoFileResultDtoDownloaded>();
                downloadManager.CheckDownloaded(dto);
                this.Files = new ObservableCollection<VideoFileResultDtoDownloaded>(dto);
            };
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
            await _downloadManager.DownloadAsync(Files.First(x => x.Id == id));
        }

        [RelayCommand]
        public async Task DeleteDownloadVideo(int id)
        {
            await _downloadManager.DeleteDownloaded(id);
        }

        private readonly INavigationService _navigationService;
        private readonly DownloadManager _downloadManager;
    }
}
