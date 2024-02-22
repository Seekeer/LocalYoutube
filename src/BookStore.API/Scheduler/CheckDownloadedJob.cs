using API.FilmDownload;
using FileStore.Domain;
using Microsoft.Extensions.DependencyInjection;
using Quartz;
using System;
using System.Threading.Tasks;

namespace Infrastructure.Scheduler
{
    [DisallowConcurrentExecution]
    public class CheckDownloadedJob : IJob
    {
        private readonly IServiceProvider _service;

        public CheckDownloadedJob(IServiceProvider service, AppConfig appConfig) 
        {
            _service = service;
        }

        public async Task Execute(IJobExecutionContext context)
        {
            var manager = _service.GetService<DbUpdateManager>();
            var tgBot = _service.GetService<TgBot>();

            var updated = manager.UpdateDownloading((info) => info.IsDownloading);
            await tgBot.NotifyDownloaded(updated);
        }
    }
}
