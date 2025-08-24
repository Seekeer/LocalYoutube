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
    public class ErrorHandlingIntegrationTests
    {
        private readonly Mock<IScriptManager> _mockScriptManager;
        private readonly Mock<ILinuxDependencyManager> _mockDependencyManager;
        private readonly Mock<IDownloadLogger> _mockDownloadLogger;
        private readonly Mock<IErrorRecoveryService> _mockErrorRecoveryService;
        private readonly AppConfig _config;

        public ErrorHandlingIntegrationTests()
        {
            _mockScriptManager = new Mock<IScriptManager>();
            _mockDependencyManager = new Mock<ILinuxDependencyManager>();
            _mockDownloadLogger = new Mock<IDownloadLogger>();
            _mockErrorRecoveryService = new Mock<IErrorRecoveryService>();
            
            _config = new AppConfig
            {
                UseProxy = false
            };
        }

        [Fact]
        public async Task WindowsDownloadService_MissingExecutable_ShouldThrowMissingExecutableException()
        {
            // Arrange
            var service = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            _mockErrorRecoveryService.Setup(x => x.TryRecoverFromMissingExecutableAsync(It.IsAny<MissingExecutableException>()))
                .ReturnsAsync(false);

            // Act & Assert
            var exception = await Assert.ThrowsAsync<MissingExecutableException>(
                () => service.Download("https://example.com/video", "test.mp4"));

            Assert.Equal(OSPlatform.Windows, exception.Platform);
            Assert.Equal("yt-dlp.exe", exception.ExecutableName);
        }

        [Fact]
        public async Task LinuxDownloadService_DependencyCheckFails_ShouldThrowDependencyException()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            _mockDependencyManager.Setup(x => x.CheckDependenciesAsync())
                .ReturnsAsync(false);

            _mockDependencyManager.Setup(x => x.GetDependencyStatusAsync())
                .ReturnsAsync(new Dictionary<string, bool> { { "yt-dlp", false } });

            _mockDependencyManager.Setup(x => x.InstallMissingDependenciesAsync())
                .ReturnsAsync(new Dictionary<string, bool> { { "yt-dlp", false } });

            _mockDependencyManager.Setup(x => x.GetMissingDependenciesErrorAsync())
                .ReturnsAsync("yt-dlp is not installed");

            _mockErrorRecoveryService.Setup(x => x.GetTroubleshootingInfo(It.IsAny<DependencyException>()))
                .Returns("Install yt-dlp");

            // Act & Assert
            var exception = await Assert.ThrowsAsync<DependencyException>(
                () => service.Download("https://example.com/video", "test.mp4"));

            Assert.Equal(OSPlatform.Linux, exception.Platform);
            Assert.Equal("yt-dlp", exception.DependencyName);
        }

        [Fact]
        public async Task LinuxDownloadService_ScriptExecutionFails_ShouldThrowScriptExecutionException()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            // Setup successful dependency check
            _mockDependencyManager.Setup(x => x.CheckDependenciesAsync())
                .ReturnsAsync(true);

            _mockDependencyManager.Setup(x => x.GetDependencyStatusAsync())
                .ReturnsAsync(new Dictionary<string, bool> { { "yt-dlp", true }, { "ffmpeg", true } });

            // Setup script that will fail
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("exit 1"); // Script that always fails

            _mockErrorRecoveryService.Setup(x => x.IsRecoverable(It.IsAny<ScriptExecutionException>()))
                .Returns(false);

            _mockErrorRecoveryService.Setup(x => x.GetTroubleshootingInfo(It.IsAny<ScriptExecutionException>()))
                .Returns("Check script execution");

            // Act & Assert
            var exception = await Assert.ThrowsAsync<ScriptExecutionException>(
                () => service.Download("https://example.com/video", "test.mp4"));

            Assert.Equal(OSPlatform.Linux, exception.Platform);
            Assert.Equal(1, exception.ExitCode);
        }

        [Fact]
        public async Task LinuxDownloadService_RecoverableError_ShouldRetryAfterRecovery()
        {
            // Arrange
            var service = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            // Setup successful dependency check
            _mockDependencyManager.Setup(x => x.CheckDependenciesAsync())
                .ReturnsAsync(true);

            _mockDependencyManager.Setup(x => x.GetDependencyStatusAsync())
                .ReturnsAsync(new Dictionary<string, bool> { { "yt-dlp", true }, { "ffmpeg", true } });

            var callCount = 0;
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns(() =>
                {
                    callCount++;
                    return callCount == 1 ? "exit 1" : "echo 'success'"; // Fail first time, succeed second time
                });

            _mockErrorRecoveryService.Setup(x => x.IsRecoverable(It.IsAny<ScriptExecutionException>()))
                .Returns(true);

            _mockErrorRecoveryService.Setup(x => x.TryRecoverFromScriptExecutionAsync(It.IsAny<ScriptExecutionException>()))
                .ReturnsAsync(true);

            // Create a temporary file to simulate successful download
            var tempFile = Path.GetTempFileName();
            File.WriteAllText(tempFile, "test content");

            try
            {
                // Act - This should succeed after recovery
                var result = await service.Download("https://example.com/video", tempFile);

                // Assert
                Assert.Equal(tempFile, result);
                _mockErrorRecoveryService.Verify(x => x.TryRecoverFromScriptExecutionAsync(It.IsAny<ScriptExecutionException>()), Times.Once);
            }
            finally
            {
                if (File.Exists(tempFile))
                    File.Delete(tempFile);
            }
        }

        [Fact]
        public void DownloadServiceBase_HandleFileMoving_FileNotFound_ShouldThrowPlatformFileOperationException()
        {
            // Arrange
            var service = new TestDownloadService(_config);
            var nonExistentFile = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
            var targetPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());

            // Act & Assert
            var exception = Assert.Throws<PlatformFileOperationException>(
                () => service.TestHandleFileMoving(nonExistentFile, targetPath));

            Assert.Contains("move", exception.Operation);
            Assert.Equal(targetPath, exception.FilePath);
        }

        [Fact]
        public void DownloadServiceBase_HandleFileMoving_SuccessfulMove_ShouldReturnTargetPath()
        {
            // Arrange
            var service = new TestDownloadService(_config);
            var sourceFile = Path.GetTempFileName();
            var targetPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".mp4");

            try
            {
                File.WriteAllText(sourceFile, "test content");

                // Act
                var result = service.TestHandleFileMoving(sourceFile, targetPath);

                // Assert
                Assert.Equal(targetPath, result);
                Assert.True(File.Exists(targetPath));
                Assert.False(File.Exists(sourceFile));
            }
            finally
            {
                if (File.Exists(sourceFile))
                    File.Delete(sourceFile);
                if (File.Exists(targetPath))
                    File.Delete(targetPath);
            }
        }

        [Fact]
        public void DownloadServiceBase_HandleFileMoving_WithHashSuffix_ShouldMoveCorrectFile()
        {
            // Arrange
            var service = new TestDownloadService(_config);
            var baseFileName = Path.GetTempFileName();
            var sourceFileWithHash = baseFileName + "#";
            var targetPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".mp4");

            try
            {
                // Delete the base file and create the one with hash suffix
                File.Delete(baseFileName);
                File.WriteAllText(sourceFileWithHash, "test content");

                // Act
                var result = service.TestHandleFileMoving(baseFileName, targetPath);

                // Assert
                Assert.Equal(targetPath, result);
                Assert.True(File.Exists(targetPath));
                Assert.False(File.Exists(sourceFileWithHash));
            }
            finally
            {
                if (File.Exists(baseFileName))
                    File.Delete(baseFileName);
                if (File.Exists(sourceFileWithHash))
                    File.Delete(sourceFileWithHash);
                if (File.Exists(targetPath))
                    File.Delete(targetPath);
            }
        }

        [Fact]
        public void DownloadServiceBase_HandleFileMoving_WithMp4Extension_ShouldMoveCorrectFile()
        {
            // Arrange
            var service = new TestDownloadService(_config);
            var baseFileName = Path.GetTempFileName();
            var sourceFileWithMp4 = baseFileName + ".mp4";
            var targetPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".mp4");

            try
            {
                // Delete the base file and create the one with .mp4 extension
                File.Delete(baseFileName);
                File.WriteAllText(sourceFileWithMp4, "test content");

                // Act
                var result = service.TestHandleFileMoving(baseFileName, targetPath);

                // Assert
                Assert.Equal(targetPath, result);
                Assert.True(File.Exists(targetPath));
                Assert.False(File.Exists(sourceFileWithMp4));
            }
            finally
            {
                if (File.Exists(baseFileName))
                    File.Delete(baseFileName);
                if (File.Exists(sourceFileWithMp4))
                    File.Delete(sourceFileWithMp4);
                if (File.Exists(targetPath))
                    File.Delete(targetPath);
            }
        }

        // Test helper class to expose protected methods
        private class TestDownloadService : DownloadServiceBase
        {
            public TestDownloadService(AppConfig config) : base(config) { }

            public override Task<string> Download(string url, string path)
            {
                throw new NotImplementedException();
            }

            public string TestHandleFileMoving(string downloadedFileName, string targetPath)
            {
                return HandleFileMoving(downloadedFileName, targetPath);
            }
        }
    }
}