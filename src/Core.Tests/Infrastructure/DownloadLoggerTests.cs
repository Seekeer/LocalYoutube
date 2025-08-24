using System;
using System.IO;
using System.Runtime.InteropServices;
using BookStore.Domain.Exceptions;
using BookStore.Infrastructure.Services;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Core.Tests.Infrastructure
{
    public class DownloadLoggerTests
    {
        private readonly Mock<ILogger<DownloadLogger>> _mockLogger;
        private readonly DownloadLogger _downloadLogger;

        public DownloadLoggerTests()
        {
            _mockLogger = new Mock<ILogger<DownloadLogger>>();
            _downloadLogger = new DownloadLogger(_mockLogger.Object);
        }

        [Fact]
        public void LogDownloadStart_ShouldLogWithCorrectParameters()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var url = "https://example.com/video";
            var targetPath = "/tmp/video.mp4";

            // Act
            _downloadLogger.LogDownloadStart(platform, url, targetPath);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Information,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Starting download") && 
                                                 v.ToString().Contains("Linux") &&
                                                 v.ToString().Contains("example.com")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogDownloadSuccess_ShouldLogWithDuration()
        {
            // Arrange
            var platform = OSPlatform.Windows;
            var url = "https://example.com/video";
            var finalPath = @"C:\videos\video.mp4";
            var duration = TimeSpan.FromSeconds(30);

            // Act
            _downloadLogger.LogDownloadSuccess(platform, url, finalPath, duration);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Information,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Download completed successfully") && 
                                                 v.ToString().Contains("Windows") &&
                                                 v.ToString().Contains("30000")), // 30 seconds in milliseconds
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogDownloadFailure_WithPlatformSpecificException_ShouldLogAsWarning()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var url = "https://example.com/video";
            var targetPath = "/tmp/video.mp4";
            var exception = new MissingExecutableException(platform, "yt-dlp", "Install instructions");
            var standardOutput = "Some output";
            var standardError = "Some error";

            // Act
            _downloadLogger.LogDownloadFailure(platform, url, targetPath, exception, standardOutput, standardError);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Warning,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Download failed") && 
                                                 v.ToString().Contains("Linux")),
                    exception,
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);

            // Should also log standard output and error
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Debug,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("StandardOutput")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);

            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Warning,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("StandardError")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogDownloadFailure_WithGenericException_ShouldLogAsError()
        {
            // Arrange
            var platform = OSPlatform.Windows;
            var url = "https://example.com/video";
            var targetPath = @"C:\videos\video.mp4";
            var exception = new InvalidOperationException("Generic error");

            // Act
            _downloadLogger.LogDownloadFailure(platform, url, targetPath, exception);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Error,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Download failed") && 
                                                 v.ToString().Contains("Windows")),
                    exception,
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogScriptExecution_ShouldLogScriptDetails()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var scriptContent = "#!/bin/bash\necho 'test'";
            var workingDirectory = "/tmp";

            // Act
            _downloadLogger.LogScriptExecution(platform, scriptContent, workingDirectory);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Debug,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Executing script") && 
                                                 v.ToString().Contains("Linux") &&
                                                 v.ToString().Contains("/tmp")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);

            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Trace,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Script content") && 
                                                 v.ToString().Contains("echo 'test'")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogScriptResult_WithSuccessfulExitCode_ShouldLogAsDebug()
        {
            // Arrange
            var platform = OSPlatform.Windows;
            var exitCode = 0;
            var standardOutput = "Success output";
            var standardError = "";
            var duration = TimeSpan.FromMilliseconds(500);

            // Act
            _downloadLogger.LogScriptResult(platform, exitCode, standardOutput, standardError, duration);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Debug,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Script execution completed") && 
                                                 v.ToString().Contains("ExitCode=0") &&
                                                 v.ToString().Contains("500")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogScriptResult_WithFailureExitCode_ShouldLogAsWarning()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var exitCode = 1;
            var standardOutput = "";
            var standardError = "Error occurred";
            var duration = TimeSpan.FromMilliseconds(1000);

            // Act
            _downloadLogger.LogScriptResult(platform, exitCode, standardOutput, standardError, duration);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Warning,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Script execution completed") && 
                                                 v.ToString().Contains("ExitCode=1")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);

            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Warning,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("StandardError") && 
                                                 v.ToString().Contains("Error occurred")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogDependencyCheck_Available_ShouldLogAsInformation()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var dependencyName = "yt-dlp";
            var version = "2023.01.06";
            var location = "/usr/local/bin/yt-dlp";

            // Act
            _downloadLogger.LogDependencyCheck(platform, dependencyName, true, version, location);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Information,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Dependency check") && 
                                                 v.ToString().Contains("yt-dlp") &&
                                                 v.ToString().Contains("is available") &&
                                                 v.ToString().Contains("2023.01.06")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogDependencyCheck_NotAvailable_ShouldLogAsWarning()
        {
            // Arrange
            var platform = OSPlatform.Windows;
            var dependencyName = "ffmpeg.exe";

            // Act
            _downloadLogger.LogDependencyCheck(platform, dependencyName, false);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Warning,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Dependency check") && 
                                                 v.ToString().Contains("ffmpeg.exe") &&
                                                 v.ToString().Contains("is NOT available")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogFileOperation_Successful_ShouldLogAsDebug()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var operation = "move";
            var filePath = "/tmp/file.txt";

            // Act
            _downloadLogger.LogFileOperation(platform, operation, filePath, true);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Debug,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("File operation succeeded") && 
                                                 v.ToString().Contains("move") &&
                                                 v.ToString().Contains("/tmp/file.txt")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogFileOperation_Failed_ShouldLogAsWarning()
        {
            // Arrange
            var platform = OSPlatform.Windows;
            var operation = "delete";
            var filePath = @"C:\file.txt";
            var errorMessage = "Access denied";

            // Act
            _downloadLogger.LogFileOperation(platform, operation, filePath, false, errorMessage);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Warning,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("File operation failed") && 
                                                 v.ToString().Contains("delete") &&
                                                 v.ToString().Contains("Access denied")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogErrorRecovery_Successful_ShouldLogAsInformation()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var exception = new InvalidOperationException("Test error");
            var recoveryAction = "Install missing dependency";

            // Act
            _downloadLogger.LogErrorRecovery(platform, exception, recoveryAction, true);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Information,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Error recovery succeeded") && 
                                                 v.ToString().Contains("Install missing dependency") &&
                                                 v.ToString().Contains("InvalidOperationException")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogErrorRecovery_Failed_ShouldLogAsWarning()
        {
            // Arrange
            var platform = OSPlatform.Windows;
            var exception = new FileNotFoundException("File not found");
            var recoveryAction = "Create missing file";

            // Act
            _downloadLogger.LogErrorRecovery(platform, exception, recoveryAction, false);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Warning,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Error recovery failed") && 
                                                 v.ToString().Contains("Create missing file") &&
                                                 v.ToString().Contains("FileNotFoundException")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogTroubleshootingInfo_ShouldLogAsInformation()
        {
            // Arrange
            var exception = new MissingExecutableException(OSPlatform.Linux, "yt-dlp", "Install instructions");
            var troubleshootingInfo = "Step 1: Install yt-dlp\nStep 2: Check PATH";

            // Act
            _downloadLogger.LogTroubleshootingInfo(exception, troubleshootingInfo);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Information,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Troubleshooting information") && 
                                                 v.ToString().Contains("MissingExecutableException") &&
                                                 v.ToString().Contains("Linux") &&
                                                 v.ToString().Contains("Step 1: Install yt-dlp")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogProxyUsage_Enabled_ShouldLogAsInformation()
        {
            // Arrange
            var platform = OSPlatform.Windows;
            var proxyString = "http://user:pass@proxy.example.com:8080";

            // Act
            _downloadLogger.LogProxyUsage(platform, proxyString, true);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Information,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Proxy enabled") && 
                                                 v.ToString().Contains("Windows") &&
                                                 v.ToString().Contains("[credentials]@proxy.example.com:8080")), // Should sanitize credentials
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Fact]
        public void LogProxyUsage_Disabled_ShouldLogAsDebug()
        {
            // Arrange
            var platform = OSPlatform.Linux;

            // Act
            _downloadLogger.LogProxyUsage(platform, "", false);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Debug,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains("Proxy disabled") && 
                                                 v.ToString().Contains("Linux")),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }

        [Theory]
        [InlineData("https://example.com/video?secret=123", "https://example.com/video")]
        [InlineData("https://user:pass@example.com/path", "https://example.com/path")]
        [InlineData("invalid-url", "[URL]")]
        public void LogDownloadStart_ShouldSanitizeUrl(string inputUrl, string expectedSanitizedUrl)
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var targetPath = "/tmp/video.mp4";

            // Act
            _downloadLogger.LogDownloadStart(platform, inputUrl, targetPath);

            // Assert
            _mockLogger.Verify(
                x => x.Log(
                    LogLevel.Information,
                    It.IsAny<EventId>(),
                    It.Is<It.IsAnyType>((v, t) => v.ToString().Contains(expectedSanitizedUrl)),
                    It.IsAny<Exception>(),
                    It.IsAny<Func<It.IsAnyType, Exception, string>>()),
                Times.Once);
        }
    }
}