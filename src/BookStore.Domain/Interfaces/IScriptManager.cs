using System.Runtime.InteropServices;

namespace BookStore.Domain.Interfaces
{
    /// <summary>
    /// Interface for managing platform-specific download scripts
    /// </summary>
    public interface IScriptManager
    {
        /// <summary>
        /// Gets the utilities installation script for the specified platform
        /// </summary>
        /// <param name="platform">The target operating system platform</param>
        /// <returns>The utilities script content</returns>
        string GetUtilitiesScript(OSPlatform platform);

        /// <summary>
        /// Gets the download script template for the specified platform
        /// </summary>
        /// <param name="platform">The target operating system platform</param>
        /// <param name="url">The URL to download from</param>
        /// <param name="fileName">The target file name without extension</param>
        /// <param name="proxySettings">Optional proxy configuration string</param>
        /// <returns>The complete download script with parameters substituted</returns>
        string GetDownloadScript(OSPlatform platform, string url, string fileName, string proxySettings = "");

        /// <summary>
        /// Validates that the script content is properly formatted for the target platform
        /// </summary>
        /// <param name="platform">The target operating system platform</param>
        /// <param name="scriptContent">The script content to validate</param>
        /// <returns>True if the script is valid for the platform</returns>
        bool ValidateScript(OSPlatform platform, string scriptContent);
    }
}