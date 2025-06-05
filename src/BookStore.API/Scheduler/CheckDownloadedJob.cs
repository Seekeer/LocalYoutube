using API.FilmDownload;
using FileStore.Domain;
using Microsoft.Extensions.DependencyInjection;
using Quartz;
using System;
using System.Threading.Tasks;

namespace Infrastructure.Scheduler
{
    [DisallowConcurrentExecution]
    public class CheckDownloadedJob(IServiceProvider service) : JobBase
    {
        protected override async Task ExecuteAsync(IJobExecutionContext context)
        {
            var manager = service.GetService<DbUpdateManager>();
            var tgBot = service.GetService<TgBot>();

            var updated = manager.UpdateDownloading((info) => info.IsDownloading && !info.DoNotAutoFinish);
            await tgBot.NotifyDownloaded(updated);
        }
    }
}
