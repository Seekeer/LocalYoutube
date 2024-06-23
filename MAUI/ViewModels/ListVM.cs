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
        public ListVM(INavigationService navigationService)
        {
            _navigationService = navigationService;

            _dtoAssign = dto => this.Files = new ObservableCollection<VideoFileResultDto>(dto);
        }

        [ObservableProperty]
        ObservableCollection<VideoFileResultDto> _files;

        [RelayCommand]
        public async Task ItemTapped(VideoFileResultDto videoFileResultDto)
        {
            await _navigationService.NavigateAsync(nameof(Player), videoFileResultDto);
        }

        private readonly INavigationService _navigationService;
    }
}
