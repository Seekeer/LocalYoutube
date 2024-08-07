using Quartz;
using System;
using System.Threading.Tasks;

namespace Infrastructure.Scheduler
{
    public abstract class JobBase : IJob
    {
        public async Task Execute(IJobExecutionContext context)
        {
            await Execute();
        }

        protected abstract Task Execute();
    }

}
