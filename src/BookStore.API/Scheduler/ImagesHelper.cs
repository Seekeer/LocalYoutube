using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using Quartz;
using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using TL;

namespace Infrastructure.Scheduler
{
    public class ImagesHelper ()
    {
        public static async Task<byte[]> GetCover(int id)
        {
            return await File.ReadAllBytesAsync(GetFilePath(id));
        }
        const string folder = @"U:\MyFiles\Apps\VideoServer\Covers";

        
        public static async Task SaveImage(int fileId, byte[] cover)
        {
            if (cover != null)
            {
                using (var ms = new MemoryStream(cover))
                {
                    using (var fs = new FileStream(GetFilePath(fileId), FileMode.Create))
                    {
                        ms.WriteTo(fs);
                    }
                }
            }

        }

        public async Task Execute(IJobExecutionContext context)
        {
            //NLog.LogManager.GetCurrentClassLogger().Info($"Job started");

            //var infos = videoCatalogContext.FilesInfo.AsTracking().Include(x =>x.DbFile)
            //    .ToList();
            //foreach (var item in infos)
            //{
            //    var cover = item.Cover;
            //    if (cover != null)
            //    {
            //        using (var ms = new MemoryStream(cover))
            //        {
            //            using (var fs = new FileStream(GetFilePath(item.DbFile.Id), FileMode.Create))
            //            {
            //                ms.WriteTo(fs);
            //            }
            //        }
            //    }
            //}
        }

        private static string GetFilePath(int fileId)
        {
            return Path.Combine(folder, fileId.ToString());
        }
    }

}
