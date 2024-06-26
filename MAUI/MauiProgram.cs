using MAUI.Pages;
using MAUI.Services;
using MAUI.ViewModels;
using Microsoft.Extensions.Logging;
using CommunityToolkit.Maui;
using FileStore.Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using Infrastructure.Context;
using FileStore.Infrastructure.Repositories;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Domain.Services;

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
                .UseMauiCommunityToolkit()
                .UseMauiCommunityToolkitMediaElement()
                .ConfigureFonts(fonts =>
                {
                    fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                    fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
                });

            //Barrel.ApplicationId = "dotnetpodcasts";

#if DEBUG
    		builder.Logging.AddDebug();
#endif

            var app =  builder.Build();

		    app.SeedDatabase();

            return app;
        }

        public const string USER_ID = "1";
        public const int SERIES_ID = 1;
        public const int SEASON_ID = 1;
    }

    public static class BuilderExtensions
    {
        public static MauiAppBuilder ConfigureServices(this MauiAppBuilder builder)
        {
            builder.Services.AddTransient<INavigationService, NavigationService>();
            builder.Services.AddTransient<IAPIService, APIService>();
            builder.Services.AddTransient<DownloadManager, DownloadManager>();
            builder.Services.AddTransient<HttpClientAuth, HttpClientAuth>();
            builder.Services.AddSingleton<IFileSystem>(FileSystem.Current);
            builder.Services.AddTransient<LocalFilesRepo, LocalFilesRepo>();

            builder.Services.AddTransient<IFilePathProvider, DbPathProvider>();
		    builder.Services.AddTransient<IMAUIService, MAUIService>();
            builder.Services.AddTransient<IVideoFileService, VideoFileService>();
            builder.Services.AddTransient<IVideoFileRepository, VideoFileRepository>();
            builder.Services.AddTransient<ISeriesRepository, SeriesRepository>();
            builder.Services.AddTransient<IDbFileRepository, DbFileRepository>();
            builder.Services.AddTransient<MAUIDbContext, MAUIDbContext>();
            //builder.Services.AddTransient<VideoCatalogDbContext, MAUIDbContext>();
            builder.Services.AddDbContextFactory<MAUIDbContext>((services, options) =>
            {
                var dbProvider = services.GetRequiredService<IFilePathProvider>();
                var dbPath = dbProvider.GetFilePath();
                options.UseSqlite($"FileName={dbPath}");
            });

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

            // pages that are navigated to
            builder.Services.AddTransient<ButtonsPage>();
            builder.Services.AddTransient<ListPage>();
            builder.Services.AddTransient<LoginPage>();
            builder.Services.AddTransient<Player>();

            return builder;
        }

        public static MauiAppBuilder ConfigureViewModels(this MauiAppBuilder builder)
        {
            builder.Services.AddTransient<LoginVM>();
            builder.Services.AddTransient<ButtonsVM>();
            builder.Services.AddTransient<ListVM>();
            builder.Services.AddTransient<PlayerVM>();
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
