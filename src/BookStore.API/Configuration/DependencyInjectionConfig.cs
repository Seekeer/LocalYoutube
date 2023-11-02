using API.Controllers;
using API.FilmDownload;
using API.TG;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Services;
using FileStore.Infrastructure.Context;
using FileStore.Infrastructure.Repositories;
using Infrastructure;
using Infrastructure.Scheduler;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Quartz;
using System;
using System.Threading;
using System.Threading.Tasks;
using TL;

namespace FileStore.API.Configuration
{
    public static class DependencyInjectionConfig
    {
        public static IServiceCollection ResolveDependencies(this IServiceCollection services, Domain.AppConfig config)
        {
            services.AddScoped<VideoCatalogDbContext>();

            services.AddScoped<IVideoFileRepository, VideoFileRepository>();
            services.AddScoped<IAudioFileRepository, AudioFileRepository>();
            services.AddScoped<IDbFileRepository, DbFileRepository>();
            services.AddScoped<ISeriesRepository, SeriesRepository>();
            services.AddScoped<IMarksRepository, MarksRepository>();

            services.AddScoped<ISeriesService, SeriesService>();
            services.AddScoped<IAudioFileService, AudioFileService>();
            services.AddScoped<IVideoFileService, VideoFileService>();
            services.AddScoped<IDbFileService, DbFileService>();

            services.AddScoped<DbUpdateManager, DbUpdateManager>();
            services.AddScoped<IMessageProcessor, MessageProcessor>();
            services.AddSingleton<TgBot, TgBot>();
            services.AddScoped<TgAPIClient, TgAPIClient>();

            services.AddHostedService<StartupService>();
            services.AddQuartz(q =>
            {
                q.ScheduleJob<BackuperJob>(trigger => trigger
                    .WithIdentity("trigger1", "group1")
                    .StartNow()
                    //.StartAt(DateBuilder.EvenSecondDate(DateTimeOffset.UtcNow.AddSeconds(7)))
                    .WithSimpleSchedule(x => x.WithInterval(TimeSpan.FromMinutes(5)).RepeatForever())
                    //.WithDailyTimeIntervalSchedule(x => x.WithIntervalInMinutes(10))
                    .WithDescription("my awesome trigger configured for a job with single call")
                );
            });
            services.AddQuartz(q =>
            {
                q.ScheduleJob<RemoveJob>(trigger => trigger
                    .WithIdentity("trigger2", "group2")
                    .StartNow()
                    .WithSimpleSchedule(x => x.WithInterval(TimeSpan.FromMinutes(5)).RepeatForever())
                    .WithDescription("my awesome trigger configured for a job with single call")
                );
            });

            // Quartz.Extensions.Hosting allows you to fire background service that handles scheduler lifecycle
            services.AddQuartzHostedService(options =>
            {
                // when shutting down we want jobs to complete gracefully
                options.WaitForJobsToComplete = true;
            });

            services.AddTransient<BackuperJob>();

            var rutracker = new RuTrackerUpdater(config);
            rutracker.Init().GetAwaiter().GetResult();
            services.AddSingleton<IRuTrackerUpdater>(rutracker);

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

                //var tgAPI = scope.ServiceProvider.GetRequiredService<TgAPIClient>();
                //await tgAPI.ImportMessages();
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