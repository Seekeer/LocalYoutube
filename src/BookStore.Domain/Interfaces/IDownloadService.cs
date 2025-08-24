using System.Threading.Tasks;

namespace BookStore.Domain.Interfaces
{
    /// <summary>
    /// Interface for download services that handle downloading content from URLs
    /// </summary>
    public interface IDownloadService
    {
        /// <summary>
        /// Downloads content from the specified URL to the given path
        /// </summary>
        /// <param name="url">The URL to download from</param>
        /// <param name="path">The local path where the content should be saved</param>
        /// <returns>The path where the content was actually saved</returns>
        Task<string> Download(string url, string path);
    }
}