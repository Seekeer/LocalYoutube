using System.Runtime.InteropServices;

namespace BookStore.Domain.Interfaces
{
    /// <summary>
    /// Service for detecting the current operating system platform
    /// </summary>
    public interface IPlatformDetectionService
    {
        /// <summary>
        /// Gets the current operating system platform
        /// </summary>
        /// <returns>The current OSPlatform</returns>
        OSPlatform GetCurrentPlatform();

        /// <summary>
        /// Determines if the current platform is Windows
        /// </summary>
        /// <returns>True if running on Windows, false otherwise</returns>
        bool IsWindows();

        /// <summary>
        /// Determines if the current platform is Linux
        /// </summary>
        /// <returns>True if running on Linux, false otherwise</returns>
        bool IsLinux();
    }
}