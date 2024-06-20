using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MAUI.Pages;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MAUI.ViewModels
{
    public partial class LoginVM : VMBase
    {
        [ObservableProperty]
        private string? _login;

        [ObservableProperty]
        private string? _password;

        [RelayCommand]
        public async Task Login()
        {
            if (string.IsNullOrEmpty(_login) || string.IsNullOrEmpty(_password))
                return;

            await CallAuthEndpoint(this);
            await TryToLogin();
        }

        private Task CallAuthEndpoint(LoginVM loginVM)
        {
            throw new NotImplementedException();
        }

        internal async Task OnNavigated()
        {
            await TryToLogin();
        }

        private async Task TryToLogin()
        {
            if (await IsAuthenticated())
                await Shell.Current.GoToAsync(nameof(ButtonsPage));
            else
                await Shell.Current.GoToAsync(nameof(LoginPage));
        }

        private async Task<bool> IsAuthenticated()
        {
            var hasAuth = await SecureStorage.GetAsync("hasAuth");
            return hasAuth != null;
        }
    }
}
