using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using FileStore.Domain.Dtos;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using MAUI.Pages;
using MAUI.Services;
using Shiny.NET;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace MAUI.ViewModels
{
    public class VideoFileResultDtoDownloaded : VideoFileResultDto
    {
        public bool IsDownloaded { get; set; }
    }

    public partial class ButtonsVM : VMBase<string>
    {
        private readonly IAPIService _api;
        private readonly INavigationService _navigationService;
        private readonly LocalFilesRepo _videoFileRepository;

        public ButtonsVM(IAPIService api, INavigationService navigationService, LocalFilesRepo localFileRepository) {
            _api = api;
            _navigationService = navigationService;
            _videoFileRepository = localFileRepository;
        }

        [RelayCommand]
        public async Task ShowHistory()
        {
            var dtos = await _api.GetHistoryAsync();

            await _navigationService.NavigateAsync(nameof(ListPage), dtos);
        }

        [RelayCommand]
        public async Task ShowDownloaded()
        {
            //var dtos = await _videoFileRepository.GetFiles();
            //await _navigationService.NavigateAsync(nameof(ListPage), dtos);

            await _navigationService.NavigateAsync(nameof(MainPage), "фф");
        }

        [RelayCommand]
        public async Task ShowFresh()
        {
            var dtos = await _api.GetFreshAsync();

            await _navigationService.NavigateAsync(nameof(ListPage), dtos);
        }

    }
}
