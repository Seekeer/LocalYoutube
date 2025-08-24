using System;
using System.IO;
using System.Runtime.InteropServices;
using BookStore.Domain.Exceptions;
using Xunit;

namespace Core.Tests.FilmDownload
{
    public class PlatformSpecificExceptionTests
    {
        [Fact]
        public void MissingExecutableException_ShouldContainCorrectInformation()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var executableName = "yt-dlp";
            var instructions = "Install with pip3 install yt-dlp";

            // Act
            var exception = new MissingExecutableException(platform, executableName, instructions);

            // Assert
            Assert.Equal(platform, exception.Platform);
            Assert.Equal(executableName, exception.ExecutableName);
            Assert.Equal(instructions, exception.InstallationInstructions);
            Assert.Contains(executableName, exception.Message);
            Assert.Contains(platform.ToString(), exception.Message);
        }

        [Fact]
        public void MissingExecutableException_WithInnerException_ShouldPreserveInnerException()
        {
            // Arrange
            var platform = OSPlatform.Windows;
            var executableName = "ffmpeg.exe";
            var instructions = "Download from ffmpeg.org";
            var innerException = new InvalidOperationException("Inner error");

            // Act
            var exception = new MissingExecutableException(platform, executableName, instructions, innerException);

            // Assert
            Assert.Equal(innerException, exception.InnerException);
            Assert.Equal(platform, exception.Platform);
            Assert.Equal(executableName, exception.ExecutableName);
            Assert.Equal(instructions, exception.InstallationInstructions);
        }

        [Fact]
        public void ScriptExecutionException_ShouldContainExecutionDetails()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var scriptContent = "#!/bin/bash\necho 'test'";
            var standardOutput = "test output";
            var standardError = "test error";
            var exitCode = 1;

            // Act
            var exception = new ScriptExecutionException(platform, scriptContent, standardOutput, standardError, exitCode);

            // Assert
            Assert.Equal(platform, exception.Platform);
            Assert.Equal(scriptContent, exception.ScriptContent);
            Assert.Equal(standardOutput, exception.StandardOutput);
            Assert.Equal(standardError, exception.StandardError);
            Assert.Equal(exitCode, exception.ExitCode);
            Assert.Contains(exitCode.ToString(), exception.Message);
            Assert.Contains(platform.ToString(), exception.Message);
        }

        [Fact]
        public void PlatformFileOperationException_ShouldContainFileOperationDetails()
        {
            // Arrange
            var platform = OSPlatform.Windows;
            var filePath = @"C:\test\file.txt";
            var operation = "move";
            var message = "Access denied";

            // Act
            var exception = new PlatformFileOperationException(platform, filePath, operation, message);

            // Assert
            Assert.Equal(platform, exception.Platform);
            Assert.Equal(filePath, exception.FilePath);
            Assert.Equal(operation, exception.Operation);
            Assert.Contains(filePath, exception.Message);
            Assert.Contains(operation, exception.Message);
            Assert.Contains(message, exception.Message);
            Assert.Contains(platform.ToString(), exception.Message);
        }

        [Fact]
        public void DependencyException_ShouldContainDependencyDetails()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var dependencyName = "python3-pip";
            var message = "Package not found";
            var recommendedAction = "Run: sudo apt install python3-pip";

            // Act
            var exception = new DependencyException(platform, dependencyName, message, recommendedAction);

            // Assert
            Assert.Equal(platform, exception.Platform);
            Assert.Equal(dependencyName, exception.DependencyName);
            Assert.Equal(recommendedAction, exception.RecommendedAction);
            Assert.Contains(dependencyName, exception.Message);
            Assert.Contains(message, exception.Message);
            Assert.Contains(platform.ToString(), exception.Message);
        }

        [Fact]
        public void PlatformSpecificException_PlatformName_Windows_ShouldReturnCorrectString()
        {
            // Arrange & Act
            var exception = new MissingExecutableException(OSPlatform.Windows, "test", "test instructions");

            // Assert
            Assert.Equal("Windows", exception.PlatformName);
        }

        [Fact]
        public void PlatformSpecificException_PlatformName_Linux_ShouldReturnCorrectString()
        {
            // Arrange & Act
            var exception = new MissingExecutableException(OSPlatform.Linux, "test", "test instructions");

            // Assert
            Assert.Equal("Linux", exception.PlatformName);
        }

        [Fact]
        public void ScriptExecutionException_WithInnerException_ShouldPreserveAllDetails()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var scriptContent = "test script";
            var standardOutput = "output";
            var standardError = "error";
            var exitCode = 2;
            var innerException = new TimeoutException("Process timeout");

            // Act
            var exception = new ScriptExecutionException(platform, scriptContent, standardOutput, 
                standardError, exitCode, innerException);

            // Assert
            Assert.Equal(innerException, exception.InnerException);
            Assert.Equal(platform, exception.Platform);
            Assert.Equal(scriptContent, exception.ScriptContent);
            Assert.Equal(standardOutput, exception.StandardOutput);
            Assert.Equal(standardError, exception.StandardError);
            Assert.Equal(exitCode, exception.ExitCode);
        }

        [Fact]
        public void PlatformFileOperationException_WithInnerException_ShouldPreserveAllDetails()
        {
            // Arrange
            var platform = OSPlatform.Windows;
            var filePath = @"C:\test.txt";
            var operation = "delete";
            var message = "File in use";
            var innerException = new IOException("File locked");

            // Act
            var exception = new PlatformFileOperationException(platform, filePath, operation, message, innerException);

            // Assert
            Assert.Equal(innerException, exception.InnerException);
            Assert.Equal(platform, exception.Platform);
            Assert.Equal(filePath, exception.FilePath);
            Assert.Equal(operation, exception.Operation);
            Assert.Contains(message, exception.Message);
        }

        [Fact]
        public void DependencyException_WithInnerException_ShouldPreserveAllDetails()
        {
            // Arrange
            var platform = OSPlatform.Linux;
            var dependencyName = "curl";
            var message = "Installation failed";
            var recommendedAction = "Check internet connection";
            var innerException = new InvalidOperationException("Network error");

            // Act
            var exception = new DependencyException(platform, dependencyName, message, recommendedAction, innerException);

            // Assert
            Assert.Equal(innerException, exception.InnerException);
            Assert.Equal(platform, exception.Platform);
            Assert.Equal(dependencyName, exception.DependencyName);
            Assert.Equal(recommendedAction, exception.RecommendedAction);
        }
    }
}