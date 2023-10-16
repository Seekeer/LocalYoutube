using FileStore.Domain;
using FileStore.Domain.Interfaces;
using Microsoft.Extensions.DependencyInjection;
using Quartz;
using System;
using System.Threading.Tasks;

namespace Infrastructure.Scheduler
{
    [DisallowConcurrentExecution]
    public class RemoveJob : IJob
    {
        private readonly IServiceProvider _service;

        public RemoveJob(IServiceProvider service)
        {
            _service = service;
        }

        public async Task Execute(IJobExecutionContext context)
        {
            using (var scope = _service.CreateScope())
            {
                var provider = scope.ServiceProvider;
                var fileRepo = provider.GetService<IDbFileRepository>();
                var fileService = provider.GetService<IDbFileService>();

                var filesToDelete = await fileRepo.Search(x => x.NeedToDelete);
                foreach (var file in filesToDelete)
                {
                    await fileService.Remove(file);
                }
            }
        }
    }
}
