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
using Quartz.Plugin.Interrupt;
using System;
using System.Globalization;
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
            //services.AddSingleton<IStartupInitService, StartupInitService>();
            services.AddScoped<TgAPIClient, TgAPIClient>();

            services.AddHostedService<StartupService>();

            services.AddQuartz(q =>
            {
                q.ScheduleJob<BackuperJob>(trigger => trigger
                    .WithIdentity("trigger1", "group1")
                    .StartNow()
                    .WithDailyTimeIntervalSchedule(s => s.OnEveryDay().StartingDailyAt(new TimeOfDay(01, 00)))
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
            services.AddQuartz(q =>
            {
                q.ScheduleJob<MoveDownloadedJob>(trigger => trigger
                    .WithIdentity("trigger3", "group3")
                    .StartNow()
                    //.WithSimpleSchedule(x => x.WithInterval(TimeSpan.FromSeconds(5)).RepeatForever())
                    .WithDailyTimeIntervalSchedule(s => s.OnEveryDay().StartingDailyAt(new TimeOfDay(14, 02)))
                );
            });
            services.AddQuartz(q =>
            {
                q.ScheduleJob<CheckDownloadedJob>(trigger => trigger
                    .WithIdentity("trigger4", "group4")
                    .StartNow()
                    .WithSimpleSchedule(x => x.WithInterval(TimeSpan.FromSeconds(5)).RepeatForever())
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
            services.AddSingleton<IRuTrackerUpdater>(rutracker);
            Task.Factory.StartNew(() => { 
                rutracker.Init().GetAwaiter().GetResult();
            });

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

                //var init = scope.ServiceProvider.GetRequiredService<IStartupInitService>();
                //await init.Init();
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