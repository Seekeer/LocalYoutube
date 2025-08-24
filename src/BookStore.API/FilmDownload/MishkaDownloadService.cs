using BookStore.Domain.Interfaces;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace API.FilmDownload
{
    public class MishkaDownloadService : IDownloadService
    {
        public async Task<string> Download(string url, string path)
        {
            var httpClient = new HttpClient();
            Thread.Sleep(1000);
            var response = await httpClient.GetAsync(url);
            var finfo = new FileInfo(path);
            Directory.CreateDirectory(finfo.DirectoryName);
            using (var fs = new FileStream(path, FileMode.CreateNew))
            {
                await response.Content.CopyToAsync(fs);
            }

            return path;
        }
    }
}