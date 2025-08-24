using System;
using System.Runtime.InteropServices;
using BookStore.Domain.Interfaces;
using FileStore.Domain;

namespace API.FilmDownload
{
    /// <summary>
    /// Factory implementation for creating platform-specific download services
    /// </summary>
    public class DownloadServiceFactory : IDownloadServiceFactory
    {
        private readonly IPlatformDetectionService _platformDetectionService;
        private readonly IScriptManager _scriptManager;
        private readonly ILinuxDependencyManager _linuxDependencyManager;
        private readonly IDownloadLogger _downloadLogger;
        private readonly IErrorRecoveryService _errorRecoveryService;

        public DownloadServiceFactory(IPlatformDetectionService platformDetectionService, IScriptManager scriptManager, 
            ILinuxDependencyManager linuxDependencyManager, IDownloadLogger downloadLogger, IErrorRecoveryService errorRecoveryService)
        {
            _platformDetectionService = platformDetectionService ?? throw new ArgumentNullException(nameof(platformDetectionService));
            _scriptManager = scriptManager ?? throw new ArgumentNullException(nameof(scriptManager));
            _linuxDependencyManager = linuxDependencyManager ?? throw new ArgumentNullException(nameof(linuxDependencyManager));
            _downloadLogger = downloadLogger ?? throw new ArgumentNullException(nameof(downloadLogger));
            _errorRecoveryService = errorRecoveryService ?? throw new ArgumentNullException(nameof(errorRecoveryService));
        }

        /// <summary>
        /// Creates an appropriate download service based on the current platform
        /// </summary>
        /// <param name="config">Application configuration</param>
        /// <returns>Platform-specific download service implementation</returns>
        /// <exception cref="ArgumentNullException">Thrown when config is null</exception>
        /// <exception cref="PlatformNotSupportedException">Thrown when platform is not supported</exception>
        public IDownloadService CreateDownloadService(AppConfig config)
        {
            if (config == null)
                throw new ArgumentNullException(nameof(config));

            var currentPlatform = _platformDetectionService.GetCurrentPlatform();

            if (currentPlatform == OSPlatform.Windows)
            {
                return new WindowsDownloadService(config, _scriptManager, _downloadLogger, _errorRecoveryService);
            }
            
            if (currentPlatform == OSPlatform.Linux)
            {
                return new LinuxDownloadService(config, _scriptManager, _linuxDependencyManager, _downloadLogger, _errorRecoveryService);
            }

            // For any other platform (including OSX), default to Linux behavior as per requirements 1.4
            throw new PlatformNotSupportedException($"Platform {currentPlatform} is not supported. Only Windows and Linux platforms are supported.");
        }
    }
}