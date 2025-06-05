using API.FilmDownload;
using Quartz;
using System;
using System.Threading.Tasks;

namespace Infrastructure.Scheduler
{
    [DisallowConcurrentExecution]
    public class CheckYoutubePlaylistJob(YoutubeCheckService checkYoutubeService) : JobBase
    {
        protected override async Task ExecuteAsync(IJobExecutionContext context)
        {
            try
            {
                await checkYoutubeService.CheckPlaylist();
                //await ResetInterval(context);
            }
            catch (System.Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);

                await PostponeTrigger(context, TimeSpan.FromHours(1));

                //await RescheduleTriggerWithIncreasedInterval(context , TimeSpan.FromMinutes(1));
            }

        }
    }
}