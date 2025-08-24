using API.FilmDownload;
using BookStore.Domain.Interfaces;
using FileStore.Domain;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;
using System.IO;

namespace Core.Tests.FilmDownload
{
    [TestClass]
    public class WindowsDownloadServiceTests
    {
        private AppConfig _config;
        private WindowsDownloadService _service;

        [TestInitialize]
        public void Setup()
        {
            _config = new AppConfig
            {
                UseProxy = false
            };
            var mockScriptManager = new Mock<IScriptManager>();
            var mockDownloadLogger = new Mock<IDownloadLogger>();
            var mockErrorRecoveryService = new Mock<IErrorRecoveryService>();
            
            _service = new WindowsDownloadService(_config, mockScriptManager.Object, mockDownloadLogger.Object, mockErrorRecoveryService.Object);
        }

        [TestMethod]
        public void PrepareFilePath_ShouldNormalizePathSeparatorsForWindows()
        {
            // Arrange
            var path = "folder/subfolder/file.mp4";
            
            // Act
            var result = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { path }) as string;

            // Assert
            Assert.IsTrue(result.Contains("\\"), "Should use backslashes for Windows");
            Assert.IsFalse(result.Contains("/"), "Should not contain forward slashes");
        }

        [TestMethod]
        public void PrepareFilePath_ShouldHandleWindowsReservedNames()
        {
            // Arrange
            var reservedNames = new[] { "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "LPT1", "LPT2" };
            
            foreach (var reservedName in reservedNames)
            {
                var path = $"{reservedName}.mp4";
                
                // Act
                var result = _service.GetType()
                    .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                    .Invoke(_service, new object[] { path }) as string;

                // Assert
                Assert.IsTrue(result.StartsWith("_"), $"Reserved name {reservedName} should be prefixed with underscore");
                Assert.IsFalse(result.StartsWith(reservedName), $"Should not start with reserved name {reservedName}");
            }
        }

        [TestMethod]
        public void PrepareFilePath_ShouldHandleWindowsReservedNamesInPath()
        {
            // Arrange
            var path = "folder\\CON.mp4";
            
            // Act
            var result = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { path }) as string;

            // Assert
            Assert.IsTrue(result.Contains("folder\\_CON.mp4"), "Reserved name in path should be prefixed with underscore");
        }

        [TestMethod]
        public void PrepareFilePath_ShouldTruncateLongPaths()
        {
            // Arrange
            var longFileName = new string('a', 300); // Very long filename
            var path = $"{longFileName}.mp4";
            
            // Act
            var result = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { path }) as string;

            // Assert
            Assert.IsTrue(result.Length <= 250, "Path should be truncated to reasonable length");
            Assert.IsTrue(result.EndsWith(".mp4"), "Extension should be preserved");
        }

        [TestMethod]
        public void PrepareFilePath_ShouldTruncateLongPathsWithDirectory()
        {
            // Arrange
            var longFileName = new string('b', 300); // Very long filename
            var path = $"folder\\{longFileName}.mp4";
            
            // Act
            var result = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { path }) as string;

            // Assert
            Assert.IsTrue(result.Length <= 250, "Path should be truncated to reasonable length");
            Assert.IsTrue(result.StartsWith("folder\\"), "Directory should be preserved");
            Assert.IsTrue(result.EndsWith(".mp4"), "Extension should be preserved");
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
        public void PrepareFilePath_ShouldInheritBaseClassSanitization()
        {
            // Arrange
            var path = "test file with spaces and 'quotes' and :*?<>|\\/ chars.mp4";
            
            // Act
            var result = _service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(_service, new object[] { path }) as string;

            // Assert
            Assert.IsFalse(result.Contains(" "), "Spaces should be removed by base class");
            Assert.IsFalse(result.Contains("'"), "Single quotes should be removed by base class");
            Assert.IsFalse(result.Contains("\""), "Double quotes should be removed by base class");
            Assert.IsFalse(result.Contains(":"), "Colons should be replaced by base class");
            Assert.IsFalse(result.Contains("*"), "Asterisks should be replaced by base class");
            Assert.IsFalse(result.Contains("?"), "Question marks should be replaced by base class");
            Assert.IsFalse(result.Contains("<"), "Less than should be replaced by base class");
            Assert.IsFalse(result.Contains(">"), "Greater than should be replaced by base class");
            Assert.IsFalse(result.Contains("|"), "Pipe should be replaced by base class");
        }
    }
}