using BookStore.Domain.Interfaces;
using FileStore.Domain;
using System.Threading.Tasks;

namespace API.FilmDownload
{
    public class RossaDownloadService : IDownloadService
    {
        private readonly IDownloadService _baseDownloadService;

        public RossaDownloadService(IDownloadService baseDownloadService)
        {
            _baseDownloadService = baseDownloadService;
        }

        public Task<string> Download(string url, string path)
        {
            // https://rossaprimavera.ru/video/da867d54 -> https://rossaprimavera.ru/static/video/da867d54/720.mp4
            url = url.Replace(@"https://rossaprimavera.ru/video", @"https://rossaprimavera.ru/static/video") + @"/720.mp4";
            return _baseDownloadService.Download(url, path);
        }
    }
}