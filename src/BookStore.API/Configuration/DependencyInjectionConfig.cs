using API.FilmDownload;
using FileStore.Domain.Interfaces;
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

            services.AddScoped<ISeriesRepository, SeriesRepository>();
            services.AddScoped<IFileRepository, FileRepository>();

            services.AddScoped<ISeriesService, SeriesService>();
            services.AddScoped<IFileService, FileService>();

            services.AddSingleton<TgBot, TgBot>();
            services.AddScoped<DbUpdateManager, DbUpdateManager>();
            
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
            using var scope = services.CreateScope();
            var tg = scope.ServiceProvider.GetRequiredService<TgBot>();

            await tg.Start();
        }

        public async Task StopAsync(CancellationToken cancellationToken)
        {
            //Cleanup logic here
        }
    }
}