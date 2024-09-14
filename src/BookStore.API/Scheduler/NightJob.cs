using Quartz;
using System;
using System.Threading.Tasks;

namespace Infrastructure.Scheduler
{
    public abstract class JobBase : IJob
    {
        public async Task Execute(IJobExecutionContext context)
        {
            NLog.LogManager.GetCurrentClassLogger().Info($"Job started");

            await Execute();
        }

        protected abstract Task Execute();
    }

}
