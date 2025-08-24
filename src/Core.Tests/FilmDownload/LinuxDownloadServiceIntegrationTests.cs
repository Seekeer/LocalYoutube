using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using API.FilmDownload;
using BookStore.Domain.Exceptions;
using BookStore.Domain.Interfaces;
using FileStore.Domain;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Core.Tests.FilmDownload
{
    /// <summary>
    /// Comprehensive integration tests for Linux download service functionality
    /// Tests Requirements: 3.1, 3.3, 4.1, 4.2
    /// </summary>
    public class LinuxDownloadServiceIntegrationTests : IDisposable
    {
        private readonly Mock<IScriptManager> _mockScriptManager;
        private readonly Mock<ILinuxDependencyManager> _mockDependencyManager;
        private readonly Mock<IDownloadLogger> _mockDownloadLogger;
        private readonly Mock<IErrorRecoveryService> _mockErrorRecoveryService;
        private readonly AppConfig _config;
        private readonly AppConfig _configWithProxy;
        private readonly List<string> _tempFiles;
        private readonly string _tempDirectory;

        public LinuxDownloadServiceIntegrationTests()
        {
            _mockScriptManager = new Mock<IScriptManager>();
            _mockDependencyManager = new Mock<ILinuxDependencyManager>();
            _mockDownloadLogger = new Mock<IDownloadLogger>();
            _mockErrorRecoveryService = new Mock<IErrorRecoveryService>();
            
            _config = new AppConfig
            {
                UseProxy = false,
                RootDownloadFolder = Path.GetTempPath()
            };

            _configWithProxy = new AppConfig
            {
                UseProxy = true,
                RootDownloadFolder = Path.GetTempPath()
            };

            _tempFiles = new List<string>();
            _tempDirectory = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
            Directory.CreateDirectory(_tempDirectory);

            SetupDefaultMocks();
        }

        private void SetupDefaultMocks()
        {
            // Setup successful dependency check by default
            _mockDependencyManager.Setup(x => x.CheckDependenciesAsync()).ReturnsAsync(true);
            _mockDependencyManager.Setup(x => x.EnsureDependenciesAsync()).ReturnsAsync(true);
            _mockDependencyManager.Setup(x => x.GetDependencyStatusAsync())
                .ReturnsAsync(new Dictionary<string, bool> { { "yt-dlp", true }, { "ffmpeg", true } });

            // Setup successful script execution by default
            _mockScriptManager.Setup(x => x.GetDownloadScript(It.IsAny<OSPlatform>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Download completed successfully'");

            // Setup error recovery as non-recoverable by default
            _mockErrorRecoveryService.Setup(x => x.IsRecoverable(It.IsAny<Exception>())).Returns(false);
        }

        #region Service Interface and Inheritance Tests

        [Fact]
        public void LinuxDownloadService_ShouldImplementIDownloadService()
        {
            // Arrange & Act
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            // Assert
            Assert.IsAssignableFrom<IDownloadService>(service);
        }

        [Fact]
        public void LinuxDownloadService_ShouldInheritFromDownloadServiceBase()
        {
            // Arrange & Act
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            // Assert
            Assert.IsAssignableFrom<DownloadServiceBase>(service);
        }

        [Fact]
        public void LinuxDownloadService_ShouldAcceptAppConfigWithProxyEnabled()
        {
            // Act
            var service = new LinuxDownloadService(_configWithProxy, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            // Assert
            Assert.NotNull(service);
        }

        #endregion

        #region Linux-Specific Functionality Tests (Requirement 3.1)

        [Fact]
        public async Task LinuxDownloadService_BasicDownload_ShouldExecuteSuccessfully()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/linux-test-video";
            var outputFile = CreateTempFile();

            // Act
            var result = await service.Download(testUrl, outputFile);

            // Assert
            Assert.Equal(outputFile, result);
            _mockDependencyManager.Verify(x => x.CheckDependenciesAsync(), Times.Once);
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            _mockDownloadLogger.Verify(x => x.LogDownloadStart(OSPlatform.Linux, testUrl, outputFile), Times.Once);
        }

        [Fact]
        public async Task LinuxDownloadService_WithDependencyCheck_ShouldEnsureDependencies()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/dependency-test-video";
            var outputFile = CreateTempFile();

            // Setup initial dependency check to fail, then succeed after ensure
            var checkCallCount = 0;
            _mockDependencyManager.Setup(x => x.CheckDependenciesAsync())
                .ReturnsAsync(() => ++checkCallCount > 1);

            _mockDependencyManager.Setup(x => x.EnsureDependenciesAsync()).ReturnsAsync(true);

            // Act
            var result = await service.Download(testUrl, outputFile);

            // Assert
            Assert.Equal(outputFile, result);
            _mockDependencyManager.Verify(x => x.CheckDependenciesAsync(), Times.AtLeast(1));
            _mockDependencyManager.Verify(x => x.EnsureDependenciesAsync(), Times.Once);
        }

        #endregion

        #region Helper Methods

        private string CreateTempFile(string fileName = null)
        {
            var tempFile = fileName != null 
                ? Path.Combine(_tempDirectory, fileName)
                : Path.Combine(_tempDirectory, Guid.NewGuid().ToString() + ".mp4");
            
            File.WriteAllText(tempFile, "test content");
            _tempFiles.Add(tempFile);
            return tempFile;
        }

        public void Dispose()
        {
            foreach (var file in _tempFiles)
            {
                if (File.Exists(file))
                {
                    try
                    {
                        File.Delete(file);
                    }
                    catch
                    {
                        // Ignore cleanup errors
                    }
                }
            }

            if (Directory.Exists(_tempDirectory))
            {
                try
                {
                    Directory.Delete(_tempDirectory, true);
                }
                catch
                {
                    // Ignore cleanup errors
                }
            }
        }

        #endregion
    }
}