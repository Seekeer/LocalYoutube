using BookStore.Domain.Interfaces;
using FileStore.Domain;
using System.Threading.Tasks;

namespace API.FilmDownload
{
    /// <summary>
    /// Default download service implementation that maintains backward compatibility
    /// Currently delegates to Windows-specific implementation
    /// </summary>
    public class DownloadService : WindowsDownloadService
    {
        public DownloadService(AppConfig config, IScriptManager scriptManager, 
            IDownloadLogger downloadLogger, IErrorRecoveryService errorRecoveryService) 
            : base(config, scriptManager, downloadLogger, errorRecoveryService)
        {
        }

        /// <summary>
        /// Downloads content using the Windows-specific implementation for backward compatibility
        /// </summary>
        /// <param name="url">The URL to download from</param>
        /// <param name="path">The local path where the content should be saved</param>
        /// <returns>The path where the content was actually saved</returns>
        public override async Task<string> Download(string url, string path)
        {
            return await base.Download(url, path);
        }
    }
}