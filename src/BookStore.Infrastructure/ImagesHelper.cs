using FileStore.Domain.Models;
using Quartz;
using System.Drawing.Drawing2D;
using System.Drawing;
using System;
using System.IO;
using System.Net;
using System.Threading.Tasks;

namespace Infrastructure
{

    public class ImagesHelper()
    {
    public async Task SetCoverByUrl( DbFile file, string url)
    {
        try
        {
            byte[] imageAsByteArray;
            using (var webClient = new WebClient())
            {
                imageAsByteArray = webClient.DownloadData(url);
            }

            await SaveImage(file.Id, imageAsByteArray);
        }
        catch (Exception)
        {
        }
    }

    private static byte[] ResizeImage(byte[] cover)
    {
        if (cover == null)
            return cover;

        System.Drawing.Image img = null;
        using (var ms = new MemoryStream(cover))
        {
            img = Image.FromStream(ms);
        }

        var maxWidth = 2000;
        if (img.Width <= maxWidth)
            return cover;

        var newImag = ResizeImage(img, maxWidth);

        using (MemoryStream memoryStream = new MemoryStream())
        {
            newImag.Save(memoryStream, System.Drawing.Imaging.ImageFormat.Jpeg);

            return memoryStream.ToArray();
        }

    }
    private static System.Drawing.Image ResizeImage(System.Drawing.Image imgToResize, int newWidth)
    {
        // Get the image current width
        int sourceWidth = imgToResize.Width;
        // Get the image current height
        int sourceHeight = imgToResize.Height;
        float nPercent = 0;
        float nPercentW = 0;
        float nPercentH = 0;
        // Calculate width and height with new desired size
        nPercentW = ((float)newWidth / (float)sourceWidth);
        //nPercentH = ((float)size.Height / (float)sourceHeight);
        //nPercent = Math.Min(nPercentW, nPercentH);
        nPercent = nPercentW;
        // New Width and Height
        int destWidth = (int)(sourceWidth * nPercent);
        int destHeight = (int)(sourceHeight * nPercent);
        Bitmap b = new Bitmap(destWidth, destHeight);
        Graphics g = Graphics.FromImage((System.Drawing.Image)b);
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        // Draw image with new width and height
        g.DrawImage(imgToResize, 0, 0, destWidth, destHeight);
        g.Dispose();
        return (System.Drawing.Image)b;
    }

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
