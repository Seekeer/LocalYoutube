using API.FilmDownload;
using FileStore.Domain;
using Microsoft.Extensions.DependencyInjection;
using Quartz;
using System;
using System.Threading.Tasks;

namespace Infrastructure.Scheduler
{
    [DisallowConcurrentExecution]
    public class CheckDownloadedJob : JobBase
    {
        private readonly IServiceProvider _service;

        public CheckDownloadedJob(IServiceProvider service, AppConfig appConfig) 
        {
            _service = service;
        }

        protected override async Task Execute()
        {
            var manager = _service.GetService<DbUpdateManager>();
            var tgBot = _service.GetService<TgBot>();

            var updated = manager.UpdateDownloading((info) => info.IsDownloading && !info.DoNotAutoFinish);
            await tgBot.NotifyDownloaded(updated);
        }
    }
}
