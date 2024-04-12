using Quartz;
using System;
using System.Threading.Tasks;

namespace Infrastructure.Scheduler
{
    public abstract class JobBase : IJob
    {
        public async Task Execute(IJobExecutionContext context)
        {
#if DEBUG
            return;
#endif
            await Execute();
        }

        protected abstract Task Execute();
    }

    public abstract class NightJob : JobBase
    {
        protected override async Task Execute()
        {
            if (DateTime.Now.Hour > 8 || DateTime.Now.Hour < 1)
                return;

            await ExecuteNightJob();
        }

        protected abstract Task ExecuteNightJob();
    }
}
