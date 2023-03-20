using API.Controllers;
using API.FilmDownload;
using API.TG;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Models;
using FileStore.Domain.Services;
using FileStore.Infrastructure.Context;
using FileStore.Infrastructure.Repositories;
using Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace FileStore.API.Configuration
{
    public static class DependencyInjectionConfig
    {
        public static IServiceCollection ResolveDependencies(this IServiceCollection services)
        {
            services.AddScoped<VideoCatalogDbContext>();

            services.AddScoped<IVideoFileRepository, VideoFileRepository>();
            services.AddScoped<IAudioFileRepository, AudioFileRepository>();
            services.AddScoped<ISeriesRepository, SeriesRepository>();

            services.AddScoped<ISeriesService, SeriesService>();
            services.AddScoped<IAudioFileService, AudioFileService>();
            services.AddScoped<IVideoFileService, VideoFileService>();

            services.AddScoped<DbUpdateManager, DbUpdateManager>();
            services.AddScoped<IMessageProcessor, MessageProcessor>();
            services.AddSingleton<TgBot, TgBot>();
            services.AddScoped<TgAPIClient, TgAPIClient>();

            services.AddHostedService<StartupService>();

            return services;
        }
    }

    public class StartupService : IHostedService
    {
        private IServiceProvider services;
        public StartupService(IServiceProvider services)
        {
            this.services = services;
        }

        public async Task StartAsync(CancellationToken cancellationToken)
        {
            try
            {
                using var scope = services.CreateScope();
                var tg = scope.ServiceProvider.GetRequiredService<TgBot>();
                await tg.Start();

                var tgAPI = scope.ServiceProvider.GetRequiredService<TgAPIClient>();
                await tgAPI.Start();
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }
        }

        public async Task StopAsync(CancellationToken cancellationToken)
        {
            //Cleanup logic here
        }
    }
}