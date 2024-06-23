using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using MAUI.Pages;
using MAUI.Services;

namespace MAUI.ViewModels
{
    public partial class ButtonsVM : VMBase<string>
    {
        private readonly IAPIService _api;
        private readonly INavigationService _navigationService;

        public ButtonsVM(IAPIService api, INavigationService navigationService) {
            _api = api;
            _navigationService = navigationService;
        }

        [RelayCommand]
        public async Task ShowHistory()
        {
            IEnumerable<VideoFileResultDto> dtos = await _api.GetHistoryAsync();

            await _navigationService.NavigateAsync(nameof(ListPage), dtos);
        }

        [RelayCommand]
        public async Task ShowDownloaded()
        {
            
        }
        
    }
}
