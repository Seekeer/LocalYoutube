using Quartz;
using System;
using System.Threading.Tasks;

namespace Infrastructure.Scheduler
{
    public abstract class NightJob : IJob
    {
        public async Task Execute(IJobExecutionContext context)
        {
#if DEBUG
            //await Execute();
            return;
#endif
            if (DateTime.Now.Hour > 8 || DateTime.Now.Hour < 1)
                return;

            await Execute();
        }

        protected abstract Task Execute();
    }
}
