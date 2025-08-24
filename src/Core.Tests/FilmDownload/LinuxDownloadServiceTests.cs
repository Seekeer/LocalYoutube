using API.FilmDownload;
using BookStore.Domain.Interfaces;
using FileStore.Domain;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;
using System.IO;
using System.Threading.Tasks;

namespace Core.Tests.FilmDownload
{
    [TestClass]
    public class LinuxDownloadServiceTests
    {
        private AppConfig _config;
        private LinuxDownloadService _service;

        [TestInitialize]
        public void Setup()
        {
            _config = new AppConfig
            {
                UseProxy = false
            };
            var mockScriptManager = new Mock<IScriptManager>();
            var mockDependencyManager = new Mock<ILinuxDependencyManager>();
            
            // Setup dependency manager to return success by default
            mockDependencyManager.Setup(x => x.CheckDependenciesAsync()).ReturnsAsync(true);
            mockDependencyManager.Setup(x => x.EnsureDependenciesAsync()).ReturnsAsync(true);
            
            _service = new LinuxDownloadService(_config, mockScriptManager.Object, mockDependencyManager.Object);
        }

        [TestMethod]
        public void PrepareFilePath_ShouldHandleLinuxSpecialCharacters()
        {
            // Arrange
            var path = "test file with spaces and `backticks` and $variables";
            
            // Act
            var result = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { path }) as string;

            // Assert
            Assert.IsFalse(result.Contains(" "), "Spaces should be removed");
            Assert.IsFalse(result.Contains("'"), "Single quotes should be removed");
            Assert.IsFalse(result.Contains("\""), "Double quotes should be removed by base class");
            Assert.IsTrue(result.Contains("\\`"), "Backticks should be escaped");
            Assert.IsTrue(result.Contains("\\$"), "Dollar signs should be escaped");
        }

        [TestMethod]
        public void PrepareFilePath_ShouldRemoveSpacesAndSingleQuotes()
        {
            // Arrange
            var path = "test file with spaces and 'single quotes'";
            
            // Act
            var result = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { path }) as string;

            // Assert
            Assert.AreEqual("testfilewithspacesandsinglequotes", result);
        }

        [TestMethod]
        public void PrepareFilePath_ShouldHandleLinuxBashSpecialCharacters()
        {
            // Arrange
            var path = "test(file)[with]{special}&chars;and!more~stuff";
            
            // Act
            var result = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { path }) as string;

            // Assert
            Assert.IsTrue(result.Contains("\\("), "Parentheses should be escaped");
            Assert.IsTrue(result.Contains("\\)"), "Parentheses should be escaped");
            Assert.IsTrue(result.Contains("\\["), "Square brackets should be escaped");
            Assert.IsTrue(result.Contains("\\]"), "Square brackets should be escaped");
            Assert.IsTrue(result.Contains("\\{"), "Curly braces should be escaped");
            Assert.IsTrue(result.Contains("\\}"), "Curly braces should be escaped");
            Assert.IsTrue(result.Contains("\\&"), "Ampersand should be escaped");
            Assert.IsTrue(result.Contains("\\;"), "Semicolon should be escaped");
            Assert.IsTrue(result.Contains("\\!"), "Exclamation mark should be escaped");
            Assert.IsTrue(result.Contains("\\~"), "Tilde should be escaped");
        }

        [TestMethod]
        public void PrepareFilePath_ShouldNormalizePathSeparatorsForLinux()
        {
            // Arrange
            var path = "folder\\subfolder\\file.mp4";
            
            // Act
            var result = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { path }) as string;

            // Assert
            Assert.IsTrue(result.Contains("/"), "Should use forward slashes for Linux");
            Assert.IsFalse(result.Contains("\\"), "Should not contain backslashes");
        }

        [TestMethod]
        public void PrepareFilePath_ShouldHandlePathsStartingWithDash()
        {
            // Arrange
            var path = "-problematic-filename.mp4";
            
            // Act
            var result = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { path }) as string;

            // Assert
            Assert.IsTrue(result.StartsWith("_"), "Paths starting with dash should be prefixed with underscore");
            Assert.IsFalse(result.StartsWith("-"), "Should not start with dash");
        }

        [TestMethod]
        public void PrepareFilePath_ShouldHandleNullAndEmptyPaths()
        {
            // Act & Assert for null
            var nullResult = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { null }) as string;
            Assert.IsNull(nullResult);

            // Act & Assert for empty string
            var emptyResult = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { "" }) as string;
            Assert.AreEqual("", emptyResult);

            // Act & Assert for whitespace
            var whitespaceResult = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { "   " }) as string;
            Assert.AreEqual("   ", whitespaceResult);
        }

        [TestMethod]
        public void CleanUrl_ShouldRemoveListParameter()
        {
            // Arrange
            var url = "https://example.com/video?v=123&list=playlist";
            
            // Act
            var result = _service.GetType()
                .GetMethod("CleanUrl", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { url }) as string;

            // Assert
            Assert.AreEqual("https://example.com/video?v=123", result);
        }

        [TestMethod]
        public void HandleFileMoving_ShouldMoveExistingFile()
        {
            // Arrange
            var tempDir = Path.GetTempPath();
            var sourceFile = Path.Combine(tempDir, "test_source.mp4");
            var targetFile = Path.Combine(tempDir, "test_target.mp4");
            
            // Create a test file
            File.WriteAllText(sourceFile, "test content");
            
            try
            {
                // Act
                var result = _service.GetType()
                    .GetMethod("HandleFileMoving", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                    .Invoke(_service, new object[] { sourceFile, targetFile }) as string;

                // Assert
                Assert.AreEqual(targetFile, result);
                Assert.IsTrue(File.Exists(targetFile), "Target file should exist");
                Assert.IsFalse(File.Exists(sourceFile), "Source file should be moved");
            }
            finally
            {
                // Cleanup
                if (File.Exists(sourceFile)) File.Delete(sourceFile);
                if (File.Exists(targetFile)) File.Delete(targetFile);
            }
        }

        [TestMethod]
        public void HandleFileMoving_ShouldHandleFileWithHashSuffix()
        {
            // Arrange
            var tempDir = Path.GetTempPath();
            var sourceFile = Path.Combine(tempDir, "test_source.mp4");
            var sourceFileWithHash = sourceFile + "#";
            var targetFile = Path.Combine(tempDir, "test_target.mp4");
            
            // Create a test file with hash suffix
            File.WriteAllText(sourceFileWithHash, "test content");
            
            try
            {
                // Act
                var result = _service.GetType()
                    .GetMethod("HandleFileMoving", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                    .Invoke(_service, new object[] { sourceFile, targetFile }) as string;

                // Assert
                Assert.AreEqual(targetFile, result);
                Assert.IsTrue(File.Exists(targetFile), "Target file should exist");
                Assert.IsFalse(File.Exists(sourceFileWithHash), "Source file with hash should be moved");
            }
            finally
            {
                // Cleanup
                if (File.Exists(sourceFileWithHash)) File.Delete(sourceFileWithHash);
                if (File.Exists(targetFile)) File.Delete(targetFile);
            }
        }

        [TestMethod]
        public void HandleFileMoving_ShouldHandleFileWithMp4Extension()
        {
            // Arrange
            var tempDir = Path.GetTempPath();
            var sourceFile = Path.Combine(tempDir, "test_source");
            var sourceFileWithMp4 = sourceFile + ".mp4";
            var targetFile = Path.Combine(tempDir, "test_target.mp4");
            
            // Create a test file with .mp4 extension
            File.WriteAllText(sourceFileWithMp4, "test content");
            
            try
            {
                // Act
                var result = _service.GetType()
                    .GetMethod("HandleFileMoving", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                    .Invoke(_service, new object[] { sourceFile, targetFile }) as string;

                // Assert
                Assert.AreEqual(targetFile, result);
                Assert.IsTrue(File.Exists(targetFile), "Target file should exist");
                Assert.IsFalse(File.Exists(sourceFileWithMp4), "Source file with .mp4 should be moved");
            }
            finally
            {
                // Cleanup
                if (File.Exists(sourceFileWithMp4)) File.Delete(sourceFileWithMp4);
                if (File.Exists(targetFile)) File.Delete(targetFile);
            }
        }

        [TestMethod]
        public void Constructor_ShouldAcceptAppConfig()
        {
            // Arrange & Act
            var mockScriptManager = new Mock<IScriptManager>();
            var mockDependencyManager = new Mock<ILinuxDependencyManager>();
            var service = new LinuxDownloadService(_config, mockScriptManager.Object, mockDependencyManager.Object);

            // Assert
            Assert.IsNotNull(service);
        }

        [TestMethod]
        public void Download_ShouldBeAsyncMethod()
        {
            // Arrange
            var url = "https://example.com/video";
            var path = "/tmp/test.mp4";

            // Act & Assert
            var downloadTask = _service.Download(url, path);
            Assert.IsInstanceOfType(downloadTask, typeof(Task<string>));
        }

        [TestMethod]
        public async Task Download_ShouldCheckDependenciesBeforeDownload()
        {
            // Arrange
            var mockScriptManager = new Mock<IScriptManager>();
            var mockDependencyManager = new Mock<ILinuxDependencyManager>();
            
            mockDependencyManager.Setup(x => x.CheckDependenciesAsync()).ReturnsAsync(false);
            mockDependencyManager.Setup(x => x.EnsureDependenciesAsync()).ReturnsAsync(true);
            mockScriptManager.Setup(x => x.GetDownloadScript(It.IsAny<System.Runtime.InteropServices.OSPlatform>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'test script'");
            
            var service = new LinuxDownloadService(_config, mockScriptManager.Object, mockDependencyManager.Object);
            var url = "https://example.com/video";
            var path = "/tmp/test.mp4";

            // Act & Assert - Should not throw exception
            try
            {
                await service.Download(url, path);
            }
            catch (System.ComponentModel.Win32Exception)
            {
                // Expected on Windows when trying to run bash
            }
            catch (System.IO.DirectoryNotFoundException)
            {
                // Expected when Assets directory doesn't exist
            }

            // Verify dependencies were checked
            mockDependencyManager.Verify(x => x.CheckDependenciesAsync(), Times.Once);
            mockDependencyManager.Verify(x => x.EnsureDependenciesAsync(), Times.Once);
        }

        [TestMethod]
        public async Task Download_ShouldThrowExceptionWhenDependenciesCannotBeEnsured()
        {
            // Arrange
            var mockScriptManager = new Mock<IScriptManager>();
            var mockDependencyManager = new Mock<ILinuxDependencyManager>();
            
            mockDependencyManager.Setup(x => x.CheckDependenciesAsync()).ReturnsAsync(false);
            mockDependencyManager.Setup(x => x.EnsureDependenciesAsync()).ReturnsAsync(false);
            mockDependencyManager.Setup(x => x.DetectPackageManagerAsync()).ReturnsAsync(BookStore.Domain.Interfaces.PackageManager.Apt);
            mockDependencyManager.Setup(x => x.GetInstallationInstructions(It.IsAny<BookStore.Domain.Interfaces.PackageManager?>()))
                .Returns("Install instructions");
            
            var service = new LinuxDownloadService(_config, mockScriptManager.Object, mockDependencyManager.Object);
            var url = "https://example.com/video";
            var path = "/tmp/test.mp4";

            // Act & Assert
            var exception = await Assert.ThrowsExceptionAsync<System.InvalidOperationException>(
                () => service.Download(url, path));
            
            Assert.IsTrue(exception.Message.Contains("Required dependencies are missing"));
            Assert.IsTrue(exception.Message.Contains("Install instructions"));
        }
    }
}