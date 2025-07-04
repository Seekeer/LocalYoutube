using API.FilmDownload;
using Quartz;
using System.Threading.Tasks;

namespace Infrastructure.Scheduler
{
    [DisallowConcurrentExecution]
    public class CheckYoutubeSubscriptionsJob(YoutubeCheckService checkYoutubeService) : JobBase
    {
        protected override async Task ExecuteAsync(IJobExecutionContext context)
        {
            await checkYoutubeService.CheckSubscriptionsUpdates();
        }
    }
}