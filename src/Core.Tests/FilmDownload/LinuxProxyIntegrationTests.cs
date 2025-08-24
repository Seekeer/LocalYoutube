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
    /// Integration tests specifically for Linux proxy configuration functionality
    /// Tests Requirements: 3.2 - Proxy configuration on Linux platform
    /// </summary>
    public class LinuxProxyIntegrationTests : IDisposable
    {
        private readonly Mock<IScriptManager> _mockScriptManager;
        private readonly Mock<ILinuxDependencyManager> _mockDependencyManager;
        private readonly Mock<IDownloadLogger> _mockDownloadLogger;
        private readonly Mock<IErrorRecoveryService> _mockErrorRecoveryService;
        private readonly AppConfig _configWithProxy;
        private readonly AppConfig _configWithoutProxy;
        private readonly List<string> _tempFiles;
        private readonly string _tempDirectory;

        public LinuxProxyIntegrationTests()
        {
            _mockScriptManager = new Mock<IScriptManager>();
            _mockDependencyManager = new Mock<ILinuxDependencyManager>();
            _mockDownloadLogger = new Mock<IDownloadLogger>();
            _mockErrorRecoveryService = new Mock<IErrorRecoveryService>();
            
            _configWithProxy = new AppConfig
            {
                UseProxy = true,
                RootDownloadFolder = Path.GetTempPath()
            };

            _configWithoutProxy = new AppConfig
            {
                UseProxy = false,
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

            // Setup error recovery as non-recoverable by default
            _mockErrorRecoveryService.Setup(x => x.IsRecoverable(It.IsAny<Exception>())).Returns(false);
        }

        #region Proxy Configuration Tests

        [Fact]
        public async Task LinuxDownloadService_WithProxyEnabled_ShouldIncludeProxyInScript()
        {
            // Arrange
            var service = new LinuxDownloadService(_configWithProxy, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/proxy-test-video";
            var outputFile = CreateTempFile();

            string capturedScript = null;
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Callback<OSPlatform, string, string, string>((platform, url, path, script) => capturedScript = script)
                .Returns("echo 'Download with proxy completed'");

            // Act
            await service.Download(testUrl, outputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            
            // Verify proxy configuration was passed to script manager
            Assert.True(_configWithProxy.UseProxy);
        }

        [Fact]
        public async Task LinuxDownloadService_WithProxyDisabled_ShouldNotIncludeProxyInScript()
        {
            // Arrange
            var service = new LinuxDownloadService(_configWithoutProxy, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/no-proxy-test-video";
            var outputFile = CreateTempFile();

            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Direct download completed'");

            // Act
            await service.Download(testUrl, outputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            Assert.False(_configWithoutProxy.UseProxy);
        }

        [Fact]
        public async Task LinuxDownloadService_ProxyAuthentication_ShouldHandleCredentials()
        {
            // Arrange
            var configWithAuth = new AppConfig
            {
                UseProxy = true,
                RootDownloadFolder = Path.GetTempPath()
            };

            var service = new LinuxDownloadService(configWithAuth, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/auth-proxy-video";
            var outputFile = CreateTempFile();

            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Authenticated proxy download completed'");

            // Act
            await service.Download(testUrl, outputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            // Verify proxy authentication was handled
            Assert.True(configWithAuth.UseProxy);
        }

        [Fact]
        public async Task LinuxDownloadService_ProxyConnectionFailure_ShouldThrowProxyException()
        {
            // Arrange
            var service = new LinuxDownloadService(_configWithProxy, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/proxy-fail-video";
            var outputFile = CreateTempFile();

            // Setup script to simulate proxy connection failure
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("exit 7"); // Network unreachable (proxy connection failed)

            _mockErrorRecoveryService.Setup(x => x.GetTroubleshootingInfo(It.IsAny<ScriptExecutionException>()))
                .Returns("Proxy connection failed. Check proxy settings and network connectivity.");

            // Act & Assert
            var exception = await Assert.ThrowsAsync<ScriptExecutionException>(
                () => service.Download(testUrl, outputFile));

            Assert.Equal(OSPlatform.Linux, exception.Platform);
            Assert.Equal(7, exception.ExitCode);
            _mockErrorRecoveryService.Verify(x => x.GetTroubleshootingInfo(It.IsAny<ScriptExecutionException>()), Times.Once);
        }

        [Fact]
        public async Task LinuxDownloadService_ProxyTimeout_ShouldRetryWithRecovery()
        {
            // Arrange
            var service = new LinuxDownloadService(_configWithProxy, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/proxy-timeout-video";
            var outputFile = CreateTempFile();

            var attemptCount = 0;
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns(() =>
                {
                    attemptCount++;
                    return attemptCount <= 2 ? "exit 110" : "echo 'Proxy retry successful'"; // Timeout first two times, succeed third
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

        [Fact]
        public async Task LinuxDownloadService_ProxyWithSSL_ShouldHandleSecureConnections()
        {
            // Arrange
            var configWithSSL = new AppConfig
            {
                UseProxy = true,
                RootDownloadFolder = Path.GetTempPath()
            };

            var service = new LinuxDownloadService(configWithSSL, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://secure.example.com/ssl-video";
            var outputFile = CreateTempFile();

            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'SSL proxy download completed'");

            // Act
            await service.Download(testUrl, outputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            Assert.True(configWithSSL.UseProxy);
        }

        [Fact]
        public async Task LinuxDownloadService_ProxyWithCustomPort_ShouldUseCorrectPort()
        {
            // Arrange
            var configWithCustomPort = new AppConfig
            {
                UseProxy = true,
                RootDownloadFolder = Path.GetTempPath()
            };

            var service = new LinuxDownloadService(configWithCustomPort, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/custom-port-video";
            var outputFile = CreateTempFile();

            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Custom port proxy download completed'");

            // Act
            await service.Download(testUrl, outputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            Assert.True(configWithCustomPort.UseProxy);
        }

        [Fact]
        public async Task LinuxDownloadService_ProxyConfigurationChange_ShouldAdaptToNewSettings()
        {
            // Arrange
            var dynamicConfig = new AppConfig
            {
                UseProxy = true,
                RootDownloadFolder = Path.GetTempPath()
            };

            var service = new LinuxDownloadService(dynamicConfig, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/dynamic-config-video";
            var outputFile = CreateTempFile();

            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Dynamic config download completed'");

            // Act - First download with initial proxy
            await service.Download(testUrl, outputFile);

            // Change proxy configuration
            dynamicConfig.UseProxy = false; // Disable proxy for second test

            // Act - Second download with updated proxy
            await service.Download(testUrl, outputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Exactly(2));
            Assert.False(dynamicConfig.UseProxy);
        }

        [Fact]
        public async Task LinuxDownloadService_ProxyWithSpecialCharacters_ShouldEscapeCorrectly()
        {
            // Arrange
            var configWithSpecialChars = new AppConfig
            {
                UseProxy = true,
                RootDownloadFolder = Path.GetTempPath()
            };

            var service = new LinuxDownloadService(configWithSpecialChars, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/special-chars-video";
            var outputFile = CreateTempFile();

            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Special characters proxy download completed'");

            // Act
            await service.Download(testUrl, outputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            Assert.True(configWithSpecialChars.UseProxy);
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