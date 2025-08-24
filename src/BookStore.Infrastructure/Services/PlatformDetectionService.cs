using System.Runtime.InteropServices;
using BookStore.Domain.Interfaces;

namespace BookStore.Infrastructure.Services
{
    /// <summary>
    /// Implementation of platform detection service using RuntimeInformation
    /// </summary>
    public class PlatformDetectionService : IPlatformDetectionService
    {
        private readonly OSPlatform _currentPlatform;

        public PlatformDetectionService()
        {
            _currentPlatform = GetDetectedPlatform();
        }

        /// <summary>
        /// Gets the current operating system platform
        /// </summary>
        /// <returns>The current OSPlatform</returns>
        public OSPlatform GetCurrentPlatform()
        {
            return _currentPlatform;
        }

        /// <summary>
        /// Determines if the current platform is Windows
        /// </summary>
        /// <returns>True if running on Windows, false otherwise</returns>
        public bool IsWindows()
        {
            return RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
        }

        /// <summary>
        /// Determines if the current platform is Linux
        /// </summary>
        /// <returns>True if running on Linux, false otherwise</returns>
        public bool IsLinux()
        {
            return RuntimeInformation.IsOSPlatform(OSPlatform.Linux);
        }

        /// <summary>
        /// Detects the current platform using RuntimeInformation
        /// </summary>
        /// <returns>The detected OSPlatform, defaults to Linux if unknown</returns>
        private static OSPlatform GetDetectedPlatform()
        {
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                return OSPlatform.Windows;
            }
            
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                return OSPlatform.Linux;
            }
            
            if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            {
                return OSPlatform.OSX;
            }
            
            // Default to Linux behavior as specified in requirements 1.4
            return OSPlatform.Linux;
        }
    }
}