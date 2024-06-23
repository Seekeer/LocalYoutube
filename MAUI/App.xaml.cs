using MAUI.Pages;

namespace MAUI
{
    public partial class App : Application
    {
        public App()
        {
            InitializeComponent();

            MainPage = new AppShell();

            this.RegisterRoutes();
        }

        private void RegisterRoutes()
        {
            Routing.RegisterRoute(nameof(LoginPage), typeof(LoginPage));
            Routing.RegisterRoute(nameof(ButtonsPage), typeof(ButtonsPage));
            Routing.RegisterRoute(nameof(Player), typeof(Player));
            Routing.RegisterRoute(nameof(ListPage), typeof(ListPage));
        }
    }
}
