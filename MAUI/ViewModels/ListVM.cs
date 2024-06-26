using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using MAUI.Pages;
using MAUI.Services;
using System.Collections.ObjectModel;

namespace MAUI.ViewModels
{
    public partial class ListVM :  VMBase<IEnumerable<VideoFileResultDto>>
    {
        public ListVM(INavigationService navigationService, DownloadManager downloadManager)
        {
            _navigationService = navigationService;
            _downloadManager = downloadManager;

            DeviceDisplay.Current.MainDisplayInfoChanged += Current_MainDisplayInfoChanged;
            UpdateOrientation();

            _dtoAssign = dto => this.Files = new ObservableCollection<VideoFileResultDto>(dto);
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
        ObservableCollection<VideoFileResultDto> _files;

        [ObservableProperty]
        bool _isVerticalOrientation;
        [ObservableProperty]
        bool _isPortraitOrientation;

        [RelayCommand]
        public async Task ItemTapped(VideoFileResultDto videoFileResultDto)
        {
            await _navigationService.NavigateAsync(nameof(Player), videoFileResultDto);
        }

        [RelayCommand]
        public async Task DownloadVideo(int id)
        {
            await _downloadManager.DownloadAsync(id);
        }

        private readonly INavigationService _navigationService;
        private readonly DownloadManager _downloadManager;
    }
}
