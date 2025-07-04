using Quartz;
using System;
using System.Threading.Tasks;

namespace Infrastructure.Scheduler
{
    public abstract class JobBase : IJob
    {
        protected TimeSpan _defaultInterval;

        public async Task Execute(IJobExecutionContext context)
        {
            NLog.LogManager.GetCurrentClassLogger().Info($"Job started {this.GetType()}");

            await ExecuteAsync(context);
        }

        protected abstract Task ExecuteAsync(IJobExecutionContext context);

        protected async Task PostponeTrigger(IJobExecutionContext context, TimeSpan timeSpan)
        {
            ITrigger oldTrigger = context.Trigger;
            if (oldTrigger is ISimpleTrigger simpleTrigger)
            {
                
                ITrigger newTrigger = TriggerBuilder.Create()
                    .WithIdentity($"YoutubePlaylistTrigger-{Guid.NewGuid()}", "group5") // Unique identity
                    .ForJob(context.JobDetail.Key)
                    .StartAt(DateTimeOffset.Now.Add(timeSpan))
                    .WithSimpleSchedule(schedule => schedule
                        .WithInterval(simpleTrigger.RepeatInterval)
                        .RepeatForever())
                    .Build();

                // Replace the old trigger with the new one
                await context.Scheduler.RescheduleJob(oldTrigger.Key, newTrigger);
            }
        }
        protected async Task RescheduleTriggerWithIncreasedInterval(IJobExecutionContext context, TimeSpan timeSpan)
        {
            ITrigger oldTrigger = context.Trigger;
            if (oldTrigger is ISimpleTrigger simpleTrigger)
            {
                if (_defaultInterval == TimeSpan.Zero)
                    _defaultInterval = simpleTrigger.RepeatInterval;

                await UpdateInterval(context, oldTrigger, timeSpan);
            }
        }

        protected async Task ResetInterval(IJobExecutionContext context)
        {
            ITrigger oldTrigger = context.Trigger;
            if (oldTrigger is ISimpleTrigger simpleTrigger)
            {
                if(_defaultInterval != TimeSpan.Zero && simpleTrigger.RepeatInterval != _defaultInterval)
                    await UpdateInterval(context, oldTrigger, _defaultInterval);
            }
        }

        private static async Task UpdateInterval(IJobExecutionContext context, ITrigger oldTrigger, TimeSpan newInterval)
        {
            // Create a new trigger with the updated interval
            ITrigger newTrigger = TriggerBuilder.Create()
                .WithIdentity($"YoutubePlaylistTrigger-{Guid.NewGuid()}", "group5") // Unique identity
                .ForJob(context.JobDetail.Key)
                .StartAt(DateBuilder.FutureDate((int)newInterval.TotalSeconds, IntervalUnit.Second))
                .WithSimpleSchedule(schedule => schedule
                    .WithInterval(newInterval)
                    .RepeatForever())
                .Build();

            // Replace the old trigger with the new one
            await context.Scheduler.RescheduleJob(oldTrigger.Key, newTrigger);
        }

    }

}
