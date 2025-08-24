using FileStore.Domain;

namespace BookStore.Domain.Interfaces
{
    /// <summary>
    /// Factory interface for creating platform-specific download services
    /// </summary>
    public interface IDownloadServiceFactory
    {
        /// <summary>
        /// Creates an appropriate download service based on the current platform
        /// </summary>
        /// <param name="config">Application configuration</param>
        /// <returns>Platform-specific download service implementation</returns>
        IDownloadService CreateDownloadService(AppConfig config);
    }
}