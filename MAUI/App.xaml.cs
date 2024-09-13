using MAUI.Pages;
using MAUI.ViewModels;
using MetroLog.Maui;
using Shiny.NET;

namespace MAUI
{
    public partial class App : Application
    {
        public App()
        {
            InitializeComponent();

            MainPage = new AppShell();

            this.RegisterRoutes();

            LogController.InitializeNavigation(
                page => MainPage!.Navigation.PushModalAsync(page),
                () => MainPage!.Navigation.PopModalAsync());

            // DEBUG Shake for logs
            //var logController = new LogController();
            //logController.IsShakeEnabled = false;
        }

        public PlayerVM CurrentPlayerVM {  get; set; }

        public void PausePlay()
        {
            CurrentPlayerVM?.Page.GetMedia()?.Pause();
        }
        public void ResumePlay()
        {
            CurrentPlayerVM?.Page.GetMedia()?.Play();
        }

        private void RegisterRoutes()
        {
            Routing.RegisterRoute(nameof(LoginPage), typeof(LoginPage));
            Routing.RegisterRoute(nameof(ButtonsPage), typeof(ButtonsPage));
            Routing.RegisterRoute(nameof(Player), typeof(Player));
            Routing.RegisterRoute(nameof(ListPage), typeof(ListPage));
            Routing.RegisterRoute(nameof(SeriesPage), typeof(SeriesPage));
            Routing.RegisterRoute(nameof(FreshPage), typeof(FreshPage));

            Routing.RegisterRoute(nameof(MainPage), typeof(MainPage));
        }
    }
}
