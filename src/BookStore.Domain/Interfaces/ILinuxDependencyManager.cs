using System.Collections.Generic;
using System.Threading.Tasks;

namespace BookStore.Domain.Interfaces
{
    /// <summary>
    /// Interface for managing Linux-specific dependencies and utilities
    /// </summary>
    public interface ILinuxDependencyManager
    {
        /// <summary>
        /// Checks if all required dependencies are available
        /// </summary>
        /// <returns>True if all dependencies are available, false otherwise</returns>
        Task<bool> CheckDependenciesAsync();

        /// <summary>
        /// Ensures all required dependencies are installed and available
        /// </summary>
        /// <returns>True if dependencies are successfully ensured, false otherwise</returns>
        Task<bool> EnsureDependenciesAsync();

        /// <summary>
        /// Detects the available package manager on the system
        /// </summary>
        /// <returns>The detected package manager or null if none found</returns>
        Task<PackageManager?> DetectPackageManagerAsync();

        /// <summary>
        /// Gets installation instructions for missing dependencies
        /// </summary>
        /// <param name="packageManager">The detected package manager</param>
        /// <returns>Installation instructions string</returns>
        string GetInstallationInstructions(PackageManager? packageManager);

        /// <summary>
        /// Checks if yt-dlp is available on the system
        /// </summary>
        /// <returns>True if yt-dlp is available, false otherwise</returns>
        Task<bool> IsYtDlpAvailableAsync();

        /// <summary>
        /// Checks if ffmpeg is available on the system
        /// </summary>
        /// <returns>True if ffmpeg is available, false otherwise</returns>
        Task<bool> IsFfmpegAvailableAsync();

        /// <summary>
        /// Gets detailed dependency status information
        /// </summary>
        /// <returns>A dictionary containing the status of each dependency</returns>
        Task<Dictionary<string, bool>> GetDependencyStatusAsync();

        /// <summary>
        /// Attempts to install missing dependencies with better error handling
        /// </summary>
        /// <returns>A dictionary indicating which dependencies were successfully installed</returns>
        Task<Dictionary<string, bool>> InstallMissingDependenciesAsync();

        /// <summary>
        /// Gets a detailed error message for missing dependencies
        /// </summary>
        /// <returns>A detailed error message with installation instructions</returns>
        Task<string> GetMissingDependenciesErrorAsync();
    }

    /// <summary>
    /// Enumeration of supported Linux package managers
    /// </summary>
    public enum PackageManager
    {
        Apt,      // Ubuntu, Debian
        Yum,      // RHEL, CentOS (older versions)
        Dnf,      // Fedora, RHEL 8+, CentOS 8+
        Pacman,   // Arch Linux
        Zypper,   // openSUSE
        Apk       // Alpine Linux
    }
}