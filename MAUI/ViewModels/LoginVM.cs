using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using MAUI.Pages;
using MAUI.Services;

namespace MAUI.ViewModels
{
    public partial class LoginVM : VMBase<string>
    {
        public LoginVM(IAPIService api, INavigationService navigationService)
        {
            _navigationService = navigationService;
            _api = api;
        }

        [ObservableProperty]
        private string? _login;

        [ObservableProperty]
        private string? _password;

        [ObservableProperty]
        private bool _areCredentialsWrong;
        private readonly INavigationService _navigationService;
        private readonly IAPIService _api;

        [RelayCommand]
        public async Task DoLogin()
        {
            if (string.IsNullOrEmpty(_login) || string.IsNullOrEmpty(_password))
                return;

            SecureStorage.RemoveAll();

            await HttpClientAuth.LoginAsync(Login, Password);
            await TryToLogin();
        }

        internal async Task OnNavigated()
        {
            //await TryToLogin();
            await _navigationService.NavigateAsync(nameof(Player), new VideoFileResultDto
            {
                CoverURL = "http://80.68.9.86:55/api/Files/getFileById?fileId=54609"
                //CoverURL = $"{HttpClientAuth.BASE_API_URL}Files/getFileById?fileId={id}"
            });

        }

        private async Task TryToLogin()
        {
            if (await HttpClientAuth.IsAuthenticated())
                await _navigationService.NavigateAsync(nameof(ButtonsPage));
            else
                AreCredentialsWrong = true;
        }
    }
}
