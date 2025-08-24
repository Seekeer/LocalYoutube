using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using BookStore.Domain.Exceptions;
using BookStore.Domain.Interfaces;
using BookStore.Infrastructure.Services;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Core.Tests.Infrastructure
{
    public class ErrorRecoveryServiceTests
    {
        private readonly Mock<ILogger<ErrorRecoveryService>> _mockLogger;
        private readonly Mock<ILinuxDependencyManager> _mockDependencyManager;
        private readonly Mock<IPlatformDetectionService> _mockPlatformService;
        private readonly ErrorRecoveryService _errorRecoveryService;

        public ErrorRecoveryServiceTests()
        {
            _mockLogger = new Mock<ILogger<ErrorRecoveryService>>();
            _mockDependencyManager = new Mock<ILinuxDependencyManager>();
            _mockPlatformService = new Mock<IPlatformDetectionService>();
            
            _errorRecoveryService = new ErrorRecoveryService(
                _mockLogger.Object,
                _mockDependencyManager.Object,
                _mockPlatformService.Object);
        }

        [Fact]
        public async Task TryRecoverFromMissingExecutableAsync_LinuxPlatform_SuccessfulInstall_ReturnsTrue()
        {
            // Arrange
            var exception = new MissingExecutableException(OSPlatform.Linux, "yt-dlp", "Install instructions");
            var installResults = new Dictionary<string, bool> { { "yt-dlp", true } };
            
            _mockDependencyManager.Setup(x => x.InstallMissingDependenciesAsync())
                .ReturnsAsync(installResults);

            // Act
            var result = await _errorRecoveryService.TryRecoverFromMissingExecutableAsync(exception);

            // Assert
            Assert.True(result);
            _mockDependencyManager.Verify(x => x.InstallMissingDependenciesAsync(), Times.Once);
        }

        [Fact]
        public async Task TryRecoverFromMissingExecutableAsync_LinuxPlatform_FailedInstall_ReturnsFalse()
        {
            // Arrange
            var exception = new MissingExecutableException(OSPlatform.Linux, "yt-dlp", "Install instructions");
            var installResults = new Dictionary<string, bool> { { "yt-dlp", false } };
            
            _mockDependencyManager.Setup(x => x.InstallMissingDependenciesAsync())
                .ReturnsAsync(installResults);

            // Act
            var result = await _errorRecoveryService.TryRecoverFromMissingExecutableAsync(exception);

            // Assert
            Assert.False(result);
        }

        [Fact]
        public async Task TryRecoverFromMissingExecutableAsync_WindowsPlatform_ExecutableNotFound_ReturnsFalse()
        {
            // Arrange
            var exception = new MissingExecutableException(OSPlatform.Windows, "nonexistent.exe", "Install instructions");

            // Act
            var result = await _errorRecoveryService.TryRecoverFromMissingExecutableAsync(exception);

            // Assert
            Assert.False(result);
            _mockDependencyManager.Verify(x => x.InstallMissingDependenciesAsync(), Times.Never);
        }

        [Fact]
        public async Task TryRecoverFromScriptExecutionAsync_CommandNotFoundError_AttemptsRecovery()
        {
            // Arrange
            var scriptException = new ScriptExecutionException(
                OSPlatform.Linux, 
                "test script", 
                "", 
                "bash: yt-dlp: command not found", 
                127);

            var installResults = new Dictionary<string, bool> { { "yt-dlp", true } };
            _mockDependencyManager.Setup(x => x.InstallMissingDependenciesAsync())
                .ReturnsAsync(installResults);

            // Act
            var result = await _errorRecoveryService.TryRecoverFromScriptExecutionAsync(scriptException);

            // Assert
            Assert.True(result);
        }

        [Fact]
        public async Task TryRecoverFromScriptExecutionAsync_PermissionDeniedError_ReturnsFalse()
        {
            // Arrange
            var scriptException = new ScriptExecutionException(
                OSPlatform.Linux, 
                "test script", 
                "", 
                "Permission denied", 
                1);

            // Act
            var result = await _errorRecoveryService.TryRecoverFromScriptExecutionAsync(scriptException);

            // Assert
            Assert.False(result);
        }

        [Fact]
        public async Task TryRecoverFromScriptExecutionAsync_NetworkError_ReturnsFalse()
        {
            // Arrange
            var scriptException = new ScriptExecutionException(
                OSPlatform.Linux, 
                "test script", 
                "", 
                "network timeout occurred", 
                1);

            // Act
            var result = await _errorRecoveryService.TryRecoverFromScriptExecutionAsync(scriptException);

            // Assert
            Assert.False(result); // Network errors should be handled by retry logic, not recovery
        }

        [Fact]
        public async Task TryRecoverFromFileOperationAsync_CreateOperation_CreatesDirectory_ReturnsTrue()
        {
            // Arrange
            var exception = new PlatformFileOperationException(
                OSPlatform.Linux, 
                "/tmp/nonexistent/file.txt", 
                "create", 
                "Directory not found");

            // Act
            var result = await _errorRecoveryService.TryRecoverFromFileOperationAsync(exception);

            // Assert
            Assert.True(result);
        }

        [Fact]
        public async Task TryRecoverFromFileOperationAsync_DeleteNonExistentFile_ReturnsTrue()
        {
            // Arrange
            var exception = new PlatformFileOperationException(
                OSPlatform.Windows, 
                @"C:\nonexistent\file.txt", 
                "delete", 
                "File not found");

            // Act
            var result = await _errorRecoveryService.TryRecoverFromFileOperationAsync(exception);

            // Assert
            Assert.True(result); // Deleting non-existent file is considered successful
        }

        [Fact]
        public async Task TryRecoverFromDependencyAsync_LinuxPlatform_SuccessfulInstall_ReturnsTrue()
        {
            // Arrange
            var exception = new DependencyException(OSPlatform.Linux, "ffmpeg", "Missing dependency", "Install ffmpeg");
            var installResults = new Dictionary<string, bool> { { "ffmpeg", true } };
            
            _mockDependencyManager.Setup(x => x.InstallMissingDependenciesAsync())
                .ReturnsAsync(installResults);

            // Act
            var result = await _errorRecoveryService.TryRecoverFromDependencyAsync(exception);

            // Assert
            Assert.True(result);
        }

        [Fact]
        public async Task TryRecoverFromDependencyAsync_WindowsPlatform_ReturnsFalse()
        {
            // Arrange
            var exception = new DependencyException(OSPlatform.Windows, "ffmpeg", "Missing dependency", "Download ffmpeg");

            // Act
            var result = await _errorRecoveryService.TryRecoverFromDependencyAsync(exception);

            // Assert
            Assert.False(result); // Windows dependency recovery not implemented
        }

        [Fact]
        public void GetTroubleshootingInfo_MissingExecutableException_ReturnsDetailedInfo()
        {
            // Arrange
            var exception = new MissingExecutableException(OSPlatform.Linux, "yt-dlp", "pip3 install yt-dlp");

            // Act
            var info = _errorRecoveryService.GetTroubleshootingInfo(exception);

            // Assert
            Assert.Contains("Platform: Linux", info);
            Assert.Contains("yt-dlp", info);
            Assert.Contains("pip3 install yt-dlp", info);
            Assert.Contains("Troubleshooting Steps:", info);
        }

        [Fact]
        public void GetTroubleshootingInfo_ScriptExecutionException_ReturnsDetailedInfo()
        {
            // Arrange
            var exception = new ScriptExecutionException(
                OSPlatform.Windows, 
                "test script", 
                "output", 
                "error message", 
                1);

            // Act
            var info = _errorRecoveryService.GetTroubleshootingInfo(exception);

            // Assert
            Assert.Contains("Platform: Windows", info);
            Assert.Contains("error message", info);
            Assert.Contains("output", info);
            Assert.Contains("Troubleshooting Steps:", info);
        }

        [Fact]
        public void GetTroubleshootingInfo_PlatformFileOperationException_ReturnsDetailedInfo()
        {
            // Arrange
            var exception = new PlatformFileOperationException(
                OSPlatform.Linux, 
                "/tmp/file.txt", 
                "move", 
                "Permission denied");

            // Act
            var info = _errorRecoveryService.GetTroubleshootingInfo(exception);

            // Assert
            Assert.Contains("Platform: Linux", info);
            Assert.Contains("/tmp/file.txt", info);
            Assert.Contains("Troubleshooting Steps:", info);
        }

        [Fact]
        public void GetTroubleshootingInfo_DependencyException_ReturnsDetailedInfo()
        {
            // Arrange
            var exception = new DependencyException(
                OSPlatform.Linux, 
                "python3", 
                "Package not found", 
                "sudo apt install python3");

            // Act
            var info = _errorRecoveryService.GetTroubleshootingInfo(exception);

            // Assert
            Assert.Contains("Platform: Linux", info);
            Assert.Contains("python3", info);
            Assert.Contains("sudo apt install python3", info);
            Assert.Contains("Troubleshooting Steps:", info);
        }

        [Fact]
        public void IsRecoverable_MissingExecutableException_ReturnsTrue()
        {
            // Arrange
            var exception = new MissingExecutableException(OSPlatform.Linux, "test", "test");

            // Act
            var result = _errorRecoveryService.IsRecoverable(exception);

            // Assert
            Assert.True(result);
        }

        [Fact]
        public void IsRecoverable_DependencyException_ReturnsTrue()
        {
            // Arrange
            var exception = new DependencyException(OSPlatform.Linux, "test", "test", "test");

            // Act
            var result = _errorRecoveryService.IsRecoverable(exception);

            // Assert
            Assert.True(result);
        }

        [Fact]
        public void IsRecoverable_InvalidOperationException_ReturnsFalse()
        {
            // Arrange
            var exception = new InvalidOperationException("test message");

            // Act
            var result = _errorRecoveryService.IsRecoverable(exception);

            // Assert
            Assert.False(result);
        }

        [Fact]
        public void IsRecoverable_ArgumentException_ReturnsFalse()
        {
            // Arrange
            var exception = new ArgumentException("test message");

            // Act
            var result = _errorRecoveryService.IsRecoverable(exception);

            // Assert
            Assert.False(result);
        }

        [Fact]
        public void IsRecoverable_ScriptExecutionWithNetworkError_ReturnsTrue()
        {
            // Arrange
            var exception = new ScriptExecutionException(
                OSPlatform.Linux, 
                "script", 
                "", 
                "network timeout", 
                1);

            // Act
            var result = _errorRecoveryService.IsRecoverable(exception);

            // Assert
            Assert.True(result);
        }

        [Fact]
        public void IsRecoverable_ScriptExecutionWithPermissionError_ReturnsFalse()
        {
            // Arrange
            var exception = new ScriptExecutionException(
                OSPlatform.Linux, 
                "script", 
                "", 
                "Permission denied", 
                1);

            // Act
            var result = _errorRecoveryService.IsRecoverable(exception);

            // Assert
            Assert.False(result);
        }

        [Fact]
        public void IsRecoverable_FileOperationCreate_ReturnsTrue()
        {
            // Arrange
            var exception = new PlatformFileOperationException(
                OSPlatform.Windows, 
                "file.txt", 
                "create", 
                "error");

            // Act
            var result = _errorRecoveryService.IsRecoverable(exception);

            // Assert
            Assert.True(result);
        }

        [Fact]
        public void IsRecoverable_FileOperationDelete_ReturnsTrue()
        {
            // Arrange
            var exception = new PlatformFileOperationException(
                OSPlatform.Linux, 
                "file.txt", 
                "delete", 
                "error");

            // Act
            var result = _errorRecoveryService.IsRecoverable(exception);

            // Assert
            Assert.True(result);
        }
    }
}