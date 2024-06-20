using Microsoft.Extensions.Logging;

namespace MAUI
{
    public static class MauiProgram
    {
        public static MauiApp CreateMauiApp()
        {
            var builder = MauiApp.CreateBuilder();
            builder
                .UseMauiApp<App>()
                .ConfigureEssentials()
                .ConfigureServices()
                .ConfigurePages()
                .ConfigureViewModels()
                .ConfigureFonts(fonts =>
                {
                    fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                    fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
                });

            //Barrel.ApplicationId = "dotnetpodcasts";

#if DEBUG
    		builder.Logging.AddDebug();
#endif

            return builder.Build();
        }
    }

    public static class BuilderExtensions
    {
        public static MauiAppBuilder ConfigureServices(this MauiAppBuilder builder)
        {
//            builder.Services.AddMauiBlazorWebView();
//            builder.Services.AddSingleton<SubscriptionsService>();
//            builder.Services.AddSingleton<ShowsService>();
//            builder.Services.AddSingleton<ListenLaterService>();
//#if WINDOWS
//        builder.Services.TryAddSingleton<SharedMauiLib.INativeAudioService, SharedMauiLib.Platforms.Windows.NativeAudioService>();
//#elif ANDROID
//        builder.Services.TryAddSingleton<SharedMauiLib.INativeAudioService, SharedMauiLib.Platforms.Android.NativeAudioService>();
////#elif MACCATALYST
////        builder.Services.TryAddSingleton<SharedMauiLib.INativeAudioService, SharedMauiLib.Platforms.MacCatalyst.NativeAudioService>();
////        builder.Services.TryAddSingleton< Platforms.MacCatalyst.ConnectivityService>();
//#elif IOS
//        builder.Services.TryAddSingleton<SharedMauiLib.INativeAudioService, SharedMauiLib.Platforms.iOS.NativeAudioService>();
//#endif

//            builder.Services.TryAddTransient<WifiOptionsService>();
//            builder.Services.TryAddSingleton<PlayerService>();

//            builder.Services.AddScoped<ThemeInterop>();
//            builder.Services.AddScoped<ClipboardInterop>();
//            builder.Services.AddScoped<ListenTogetherHubClient>(_ =>
//                new ListenTogetherHubClient(Config.ListenTogetherUrl));

//            builder.Services.AddSingleton<ImageProcessingService>();

            return builder;
        }

        public static MauiAppBuilder ConfigurePages(this MauiAppBuilder builder)
        {
            //// main tabs of the app
            //builder.Services.AddSingleton<DiscoverPage>();
            //builder.Services.AddSingleton<SubscriptionsPage>();
            //builder.Services.AddSingleton<ListenLaterPage>();
            //builder.Services.AddSingleton<ListenTogetherPage>();
            //builder.Services.AddSingleton<SettingsPage>();

            //// pages that are navigated to
            //builder.Services.AddTransient<CategoriesPage>();
            //builder.Services.AddTransient<CategoryPage>();
            //builder.Services.AddTransient<EpisodeDetailPage>();
            //builder.Services.AddTransient<ShowDetailPage>();

            return builder;
        }

        public static MauiAppBuilder ConfigureViewModels(this MauiAppBuilder builder)
        {
            //builder.Services.AddSingleton<CategoriesViewModel>();
            //builder.Services.AddTransient<CategoryViewModel>();
            //builder.Services.AddSingleton<DiscoverViewModel>();
            //builder.Services.AddTransient<EpisodeDetailViewModel>();
            //builder.Services.AddSingleton<EpisodeViewModel>();
            //builder.Services.AddSingleton<ListenLaterViewModel>();
            //builder.Services.AddSingleton<SettingsViewModel>();
            //builder.Services.AddSingleton<ShellViewModel>();
            //builder.Services.AddTransient<ShowDetailViewModel>();
            //builder.Services.AddSingleton<ShowViewModel>();
            //builder.Services.AddSingleton<SubscriptionsViewModel>();

            return builder;
        }
    }
}
