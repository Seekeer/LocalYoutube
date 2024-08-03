using MAUI.Pages;
using MetroLog.Maui;
using Shiny.NET;

namespace MAUI
{
    public partial class App : Application
    {
        public App()
        {
            try
            {

                InitializeComponent();

                MainPage = new AppShell();

                this.RegisterRoutes();

                LogController.InitializeNavigation(
                    page => MainPage!.Navigation.PushModalAsync(page),
                    () => MainPage!.Navigation.PopModalAsync());

                var logController = new LogController();
                logController.IsShakeEnabled = true;
            }
            catch (Exception ex)
            {
            }
        }

        private void RegisterRoutes()
        {
            Routing.RegisterRoute(nameof(LoginPage), typeof(LoginPage));
            Routing.RegisterRoute(nameof(ButtonsPage), typeof(ButtonsPage));
            Routing.RegisterRoute(nameof(Player), typeof(Player));
            Routing.RegisterRoute(nameof(ListPage), typeof(ListPage));
            Routing.RegisterRoute(nameof(SeriesPage), typeof(SeriesPage));

            Routing.RegisterRoute(nameof(MainPage), typeof(MainPage));
        }
    }
}
