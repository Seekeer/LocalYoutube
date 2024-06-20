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
            //Routing.RegisterRoute(nameof(ShowDetailPage), typeof(ShowDetailPage));
            //Routing.RegisterRoute(nameof(EpisodeDetailPage), typeof(EpisodeDetailPage));
            //Routing.RegisterRoute(nameof(CategoriesPage), typeof(CategoriesPage));
            //Routing.RegisterRoute(nameof(CategoryPage), typeof(CategoryPage));
        }
    }
}
