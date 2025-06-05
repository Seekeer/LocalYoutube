using API.Controllers;
using FileStore.Domain;
using FileStore.Domain.Interfaces;
using Microsoft.Extensions.DependencyInjection;
using Quartz;
using System;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using TL;

namespace Infrastructure.Scheduler
{
    [DisallowConcurrentExecution]
    public class RemoveJob(IServiceProvider service) : JobBase
    {
        protected override async Task ExecuteAsync(IJobExecutionContext context)
        {
            NLog.Web.NLogBuilder.ConfigureNLog("NLog.config").GetCurrentClassLogger().Debug("Remove job started");

            using (var scope = service.CreateScope())
            {
                var provider = scope.ServiceProvider;
                var fileRepo = provider.GetService<IDbFileRepository>();
                var fileService = provider.GetService<IDbFileService>();

                var rutracker = provider.GetService<IRuTrackerUpdater>();


                var filesToDelete = await fileRepo.SearchAsync(x => x.NeedToDelete);

                NLog.Web.NLogBuilder.ConfigureNLog("NLog.config").GetCurrentClassLogger().Debug($"{filesToDelete.Count()} files to delete");

                foreach (var file in filesToDelete.OrderBy(x => Guid.NewGuid()))
                {
                    try
                    {
                        NLog.Web.NLogBuilder.ConfigureNLog("NLog.config").GetCurrentClassLogger().Debug($"Deleting {file.Id}:{file.Path}");

                        if (File.Exists(file.Path))
                        {
                            await rutracker.DeleteTorrent(file.VideoFileExtendedInfo.RutrackerId.ToString());
                            File.Delete(file.Path);
                        }
                    }
                    catch (Exception ex)
                    {
                        NLog.Web.NLogBuilder.ConfigureNLog("NLog.config").GetCurrentClassLogger().Error(ex);
                    }
                }
            }
        }
    }
}
