using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
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
            await TryToLogin();
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
