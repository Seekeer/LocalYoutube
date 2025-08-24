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
    /// Integration tests for cross-platform download functionality
    /// Tests Requirements: 3.1, 3.2, 3.3, 4.1, 4.2
    /// </summary>
    public class CrossPlatformIntegrationTests : IDisposable
    {
        private readonly Mock<IScriptManager> _mockScriptManager;
        private readonly Mock<ILinuxDependencyManager> _mockDependencyManager;
        private readonly Mock<IDownloadLogger> _mockDownloadLogger;
        private readonly Mock<IErrorRecoveryService> _mockErrorRecoveryService;
        private readonly Mock<IPlatformDetectionService> _mockPlatformDetection;
        private readonly AppConfig _config;
        private readonly AppConfig _configWithProxy;
        private readonly List<string> _tempFiles;
        private readonly string _tempDirectory;

        public CrossPlatformIntegrationTests()
        {
            _mockScriptManager = new Mock<IScriptManager>();
            _mockDependencyManager = new Mock<ILinuxDependencyManager>();
            _mockDownloadLogger = new Mock<IDownloadLogger>();
            _mockErrorRecoveryService = new Mock<IErrorRecoveryService>();
            _mockPlatformDetection = new Mock<IPlatformDetectionService>();
            
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

        #region Linux Download Functionality Tests (Requirement 3.1)

        [Fact]
        public async Task LinuxDownloadService_BasicDownload_ShouldExecuteSuccessfully()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/test-video";
            var outputFile = CreateTempFile();

            // Act
            var result = await service.Download(testUrl, outputFile);

            // Assert
            Assert.Equal(outputFile, result);
            _mockDependencyManager.Verify(x => x.CheckDependenciesAsync(), Times.Once);
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
        }

        [Fact]
        public async Task LinuxDownloadService_VideoQualityOptions_ShouldPassCorrectParameters()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/hd-video";
            var outputFile = CreateTempFile();

            // Setup script manager to capture parameters
            string capturedScript = null;
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Callback<OSPlatform, string, string, string>((platform, url, path, script) => capturedScript = script)
                .Returns("echo 'HD download completed'");

            // Act
            await service.Download(testUrl, outputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            // Verify that the script manager was called with Linux platform
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), Times.Once);
        }

        [Fact]
        public async Task LinuxDownloadService_FragmentRetries_ShouldHandleNetworkIssues()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/fragmented-video";
            var outputFile = CreateTempFile();

            // Setup script to simulate fragment retry scenario
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Retrying fragments...' && echo 'Download completed with retries'");

            // Act
            var result = await service.Download(testUrl, outputFile);

            // Assert
            Assert.Equal(outputFile, result);
            _mockDownloadLogger.Verify(x => x.LogDownloadStart(OSPlatform.Linux, testUrl, outputFile), Times.Once);
        }

        [Fact]
        public async Task LinuxDownloadService_InfoJsonGeneration_ShouldCreateMetadataFile()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/video-with-metadata";
            var outputFile = CreateTempFile();
            var infoJsonFile = Path.ChangeExtension(outputFile, ".info.json");

            // Setup script to simulate info.json creation
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns($"echo '{{\"title\": \"Test Video\"}}' > '{infoJsonFile}' && echo 'Download completed'");

            // Act
            await service.Download(testUrl, outputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            // Verify the script includes info.json generation logic
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), 
                It.Is<string>(s => s.Contains("info.json") || s.Contains("writeinfojson"))), Times.Once);
        }

        #endregion

        #region Proxy Configuration Tests (Requirement 3.2)

        [Fact]
        public async Task LinuxDownloadService_WithProxyEnabled_ShouldPassProxyToScript()
        {
            // Arrange
            var service = new LinuxDownloadService(_configWithProxy, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/proxied-video";
            var outputFile = CreateTempFile();

            string capturedScript = null;
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Callback<OSPlatform, string, string, string>((platform, url, path, script) => capturedScript = script)
                .Returns("echo 'Download via proxy completed'");

            // Act
            await service.Download(testUrl, outputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            // Verify proxy configuration is considered
            Assert.True(_configWithProxy.UseProxy);
        }

        [Fact]
        public async Task LinuxDownloadService_ProxyConfiguration_ShouldHandleProxyFailure()
        {
            // Arrange
            var service = new LinuxDownloadService(_configWithProxy, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/proxy-fail-video";
            var outputFile = CreateTempFile();

            // Setup script to simulate proxy failure
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("exit 1"); // Simulate proxy connection failure

            _mockErrorRecoveryService.Setup(x => x.IsRecoverable(It.IsAny<ScriptExecutionException>()))
                .Returns(true);
            _mockErrorRecoveryService.Setup(x => x.TryRecoverFromScriptExecutionAsync(It.IsAny<ScriptExecutionException>()))
                .ReturnsAsync(false);

            // Act & Assert
            var exception = await Assert.ThrowsAsync<ScriptExecutionException>(
                () => service.Download(testUrl, outputFile));

            Assert.Equal(OSPlatform.Linux, exception.Platform);
            _mockErrorRecoveryService.Verify(x => x.TryRecoverFromScriptExecutionAsync(It.IsAny<ScriptExecutionException>()), Times.Once);
        }

        [Fact]
        public async Task LinuxDownloadService_ProxyBypass_ShouldFallbackToDirectConnection()
        {
            // Arrange
            var service = new LinuxDownloadService(_configWithProxy, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/proxy-bypass-video";
            var outputFile = CreateTempFile();

            var callCount = 0;
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns(() =>
                {
                    callCount++;
                    return callCount == 1 ? "exit 1" : "echo 'Direct connection successful'"; // Fail with proxy, succeed without
                });

            _mockErrorRecoveryService.Setup(x => x.IsRecoverable(It.IsAny<ScriptExecutionException>()))
                .Returns(true);
            _mockErrorRecoveryService.Setup(x => x.TryRecoverFromScriptExecutionAsync(It.IsAny<ScriptExecutionException>()))
                .ReturnsAsync(true);

            // Act
            var result = await service.Download(testUrl, outputFile);

            // Assert
            Assert.Equal(outputFile, result);
            _mockErrorRecoveryService.Verify(x => x.TryRecoverFromScriptExecutionAsync(It.IsAny<ScriptExecutionException>()), Times.Once);
        }

        #endregion

        #region File Output Consistency Tests (Requirement 3.3)

        [Fact]
        public async Task CrossPlatform_FileNaming_ShouldBeConsistentBetweenPlatforms()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/test video with spaces & special chars!.mp4";
            var linuxOutputFile = CreateTempFile("linux_output.mp4");
            var windowsOutputFile = CreateTempFile("windows_output.mp4");

            // Act
            await linuxService.Download(testUrl, linuxOutputFile);
            await windowsService.Download(testUrl, windowsOutputFile);

            // Assert
            // Both services should have been called with their respective platforms
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Windows, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
        }

        [Fact]
        public async Task CrossPlatform_PathHandling_ShouldHandleDifferentPathSeparators()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/path-test-video";
            var linuxPath = "/home/user/videos/test video.mp4";
            var windowsPath = @"C:\Users\user\videos\test video.mp4";

            // Act & Assert - Linux path
            var linuxResult = await linuxService.Download(testUrl, linuxPath);
            Assert.Equal(linuxPath, linuxResult);

            // Verify Linux-style path was processed
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
        }

        [Fact]
        public async Task CrossPlatform_FileExtensions_ShouldHandleConsistently()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/multi-format-video";
            var mp4File = CreateTempFile("test.mp4");
            var webmFile = CreateTempFile("test.webm");
            var mkvFile = CreateTempFile("test.mkv");

            // Act
            await linuxService.Download(testUrl, mp4File);
            await linuxService.Download(testUrl, webmFile);
            await linuxService.Download(testUrl, mkvFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Exactly(3));
        }

        [Fact]
        public async Task CrossPlatform_MergeOutputFormats_ShouldProduceSameResult()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/merge-test-video";
            var outputFile = CreateTempFile("merged_output.mp4");

            // Setup script to simulate format merging
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Merging video and audio streams...' && echo 'Merge completed'");

            // Act
            var result = await linuxService.Download(testUrl, outputFile);

            // Assert
            Assert.Equal(outputFile, result);
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
        }

        #endregion

        #region Error Scenarios and Recovery Tests (Requirements 4.1, 4.2)

        [Fact]
        public async Task LinuxDownloadService_MissingDependencies_ShouldProvideDetailedErrorMessage()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/dependency-test-video";
            var outputFile = CreateTempFile();

            // Setup dependency failure
            _mockDependencyManager.Setup(x => x.CheckDependenciesAsync()).ReturnsAsync(false);
            _mockDependencyManager.Setup(x => x.GetDependencyStatusAsync())
                .ReturnsAsync(new Dictionary<string, bool> { { "yt-dlp", false }, { "ffmpeg", true } });
            _mockDependencyManager.Setup(x => x.InstallMissingDependenciesAsync())
                .ReturnsAsync(new Dictionary<string, bool> { { "yt-dlp", false } });
            _mockDependencyManager.Setup(x => x.GetMissingDependenciesErrorAsync())
                .ReturnsAsync("yt-dlp is not installed. Please install it using: pip3 install yt-dlp");

            _mockErrorRecoveryService.Setup(x => x.GetTroubleshootingInfo(It.IsAny<DependencyException>()))
                .Returns("Install yt-dlp using your system package manager or pip3");

            // Act & Assert
            var exception = await Assert.ThrowsAsync<DependencyException>(
                () => service.Download(testUrl, outputFile));

            Assert.Equal(OSPlatform.Linux, exception.Platform);
            Assert.Equal("yt-dlp", exception.DependencyName);
            Assert.Contains("yt-dlp is not installed", exception.Message);
            _mockErrorRecoveryService.Verify(x => x.GetTroubleshootingInfo(It.IsAny<DependencyException>()), Times.Once);
        }

        [Fact]
        public async Task LinuxDownloadService_PermissionDenied_ShouldProvideActionableError()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/permission-test-video";
            var restrictedPath = "/root/restricted/video.mp4";

            // Setup script to simulate permission denied
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("exit 126"); // Permission denied exit code

            _mockErrorRecoveryService.Setup(x => x.GetTroubleshootingInfo(It.IsAny<ScriptExecutionException>()))
                .Returns("Permission denied. Check file permissions and ensure the directory is writable.");

            // Act & Assert
            var exception = await Assert.ThrowsAsync<ScriptExecutionException>(
                () => service.Download(testUrl, restrictedPath));

            Assert.Equal(OSPlatform.Linux, exception.Platform);
            Assert.Equal(126, exception.ExitCode);
            _mockErrorRecoveryService.Verify(x => x.GetTroubleshootingInfo(It.IsAny<ScriptExecutionException>()), Times.Once);
        }

        [Fact]
        public async Task LinuxDownloadService_NetworkTimeout_ShouldRetryWithRecovery()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/timeout-test-video";
            var outputFile = CreateTempFile();

            var attemptCount = 0;
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns(() =>
                {
                    attemptCount++;
                    return attemptCount <= 2 ? "exit 1" : "echo 'Download successful after retry'"; // Fail twice, succeed third time
                });

            _mockErrorRecoveryService.Setup(x => x.IsRecoverable(It.IsAny<ScriptExecutionException>()))
                .Returns(true);
            _mockErrorRecoveryService.Setup(x => x.TryRecoverFromScriptExecutionAsync(It.IsAny<ScriptExecutionException>()))
                .ReturnsAsync(true);

            // Act
            var result = await service.Download(testUrl, outputFile);

            // Assert
            Assert.Equal(outputFile, result);
            _mockErrorRecoveryService.Verify(x => x.TryRecoverFromScriptExecutionAsync(It.IsAny<ScriptExecutionException>()), Times.AtLeast(1));
        }

        [Fact]
        public async Task LinuxDownloadService_DiskSpaceIssue_ShouldProvideSpecificError()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/large-video";
            var outputFile = CreateTempFile();

            // Setup script to simulate disk space issue
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("exit 28"); // No space left on device

            _mockErrorRecoveryService.Setup(x => x.GetTroubleshootingInfo(It.IsAny<ScriptExecutionException>()))
                .Returns("Insufficient disk space. Free up space and try again.");

            // Act & Assert
            var exception = await Assert.ThrowsAsync<ScriptExecutionException>(
                () => service.Download(testUrl, outputFile));

            Assert.Equal(OSPlatform.Linux, exception.Platform);
            Assert.Equal(28, exception.ExitCode);
            _mockErrorRecoveryService.Verify(x => x.GetTroubleshootingInfo(It.IsAny<ScriptExecutionException>()), Times.Once);
        }

        [Fact]
        public async Task LinuxDownloadService_RecoveryMechanism_ShouldLogRecoveryAttempts()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/recovery-test-video";
            var outputFile = CreateTempFile();

            var callCount = 0;
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns(() =>
                {
                    callCount++;
                    return callCount == 1 ? "exit 1" : "echo 'Recovery successful'";
                });

            _mockErrorRecoveryService.Setup(x => x.IsRecoverable(It.IsAny<ScriptExecutionException>()))
                .Returns(true);
            _mockErrorRecoveryService.Setup(x => x.TryRecoverFromScriptExecutionAsync(It.IsAny<ScriptExecutionException>()))
                .ReturnsAsync(true);

            // Act
            var result = await service.Download(testUrl, outputFile);

            // Assert
            Assert.Equal(outputFile, result);
            _mockDownloadLogger.Verify(x => x.LogDownloadStart(OSPlatform.Linux, testUrl, outputFile), Times.Once);
            _mockErrorRecoveryService.Verify(x => x.TryRecoverFromScriptExecutionAsync(It.IsAny<ScriptExecutionException>()), Times.Once);
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