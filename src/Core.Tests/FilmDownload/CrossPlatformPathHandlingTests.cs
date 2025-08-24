using API.FilmDownload;
using BookStore.Domain.Interfaces;
using FileStore.Domain;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;
using System.Collections.Generic;
using System.Linq;

namespace Core.Tests.FilmDownload
{
    [TestClass]
    public class CrossPlatformPathHandlingTests
    {
        private AppConfig _config;
        private WindowsDownloadService _windowsService;
        private LinuxDownloadService _linuxService;

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
            
            _windowsService = new WindowsDownloadService(_config, mockScriptManager.Object);
            _linuxService = new LinuxDownloadService(_config, mockScriptManager.Object, mockDependencyManager.Object);
        }

        [TestMethod]
        public void PrepareFilePath_ShouldProduceConsistentBaseResults()
        {
            // Arrange
            var testPaths = new[]
            {
                "simple_file.mp4",
                "file with spaces.mp4",
                "file'with'quotes.mp4",
                "file\"with\"doublequotes.mp4",
                "file\twith\ttabs.mp4",
                "file\nwith\nnewlines.mp4"
            };

            foreach (var testPath in testPaths)
            {
                // Act
                var windowsResult = InvokePreparePath(_windowsService, testPath);
                var linuxResult = InvokePreparePath(_linuxService, testPath);

                // Assert - Both should remove the same basic problematic characters
                Assert.IsFalse(windowsResult.Contains(" "), $"Windows should remove spaces from: {testPath}");
                Assert.IsFalse(linuxResult.Contains(" "), $"Linux should remove spaces from: {testPath}");
                
                Assert.IsFalse(windowsResult.Contains("'"), $"Windows should remove single quotes from: {testPath}");
                Assert.IsFalse(linuxResult.Contains("'"), $"Linux should remove single quotes from: {testPath}");
                
                Assert.IsFalse(windowsResult.Contains("\""), $"Windows should remove double quotes from: {testPath}");
                Assert.IsFalse(linuxResult.Contains("\""), $"Linux should remove double quotes from: {testPath}");
                
                Assert.IsFalse(windowsResult.Contains("\t"), $"Windows should remove tabs from: {testPath}");
                Assert.IsFalse(linuxResult.Contains("\t"), $"Linux should remove tabs from: {testPath}");
                
                Assert.IsFalse(windowsResult.Contains("\n"), $"Windows should remove newlines from: {testPath}");
                Assert.IsFalse(linuxResult.Contains("\n"), $"Linux should remove newlines from: {testPath}");
            }
        }

        [TestMethod]
        public void PrepareFilePath_ShouldHandlePlatformSpecificPathSeparators()
        {
            // Arrange
            var pathWithMixedSeparators = "folder/subfolder\\file.mp4";

            // Act
            var windowsResult = InvokePreparePath(_windowsService, pathWithMixedSeparators);
            var linuxResult = InvokePreparePath(_linuxService, pathWithMixedSeparators);

            // Assert
            Assert.IsTrue(windowsResult.Contains("\\"), "Windows should use backslashes");
            Assert.IsFalse(windowsResult.Contains("/"), "Windows should not contain forward slashes");
            
            Assert.IsTrue(linuxResult.Contains("/"), "Linux should use forward slashes");
            Assert.IsFalse(linuxResult.Contains("\\"), "Linux should not contain backslashes");
        }

        [TestMethod]
        public void PrepareFilePath_ShouldHandlePlatformSpecificSpecialCharacters()
        {
            // Arrange
            var pathWithSpecialChars = "file(with)[special]{chars}&more;stuff.mp4";

            // Act
            var windowsResult = InvokePreparePath(_windowsService, pathWithSpecialChars);
            var linuxResult = InvokePreparePath(_linuxService, pathWithSpecialChars);

            // Assert - Linux should escape bash special characters
            Assert.IsTrue(linuxResult.Contains("\\("), "Linux should escape parentheses");
            Assert.IsTrue(linuxResult.Contains("\\["), "Linux should escape square brackets");
            Assert.IsTrue(linuxResult.Contains("\\{"), "Linux should escape curly braces");
            Assert.IsTrue(linuxResult.Contains("\\&"), "Linux should escape ampersand");
            Assert.IsTrue(linuxResult.Contains("\\;"), "Linux should escape semicolon");

            // Windows doesn't need to escape these for PowerShell in the same way
            // but both should handle the base sanitization
        }

        [TestMethod]
        public void PrepareFilePath_ShouldHandleEdgeCases()
        {
            // Test null case
            var windowsNullResult = InvokePreparePath(_windowsService, null);
            var linuxNullResult = InvokePreparePath(_linuxService, null);
            Assert.IsNull(windowsNullResult, "Windows should handle null");
            Assert.IsNull(linuxNullResult, "Linux should handle null");

            // Test empty case
            var windowsEmptyResult = InvokePreparePath(_windowsService, "");
            var linuxEmptyResult = InvokePreparePath(_linuxService, "");
            Assert.AreEqual("", windowsEmptyResult, "Windows should handle empty string");
            Assert.AreEqual("", linuxEmptyResult, "Linux should handle empty string");

            // Test whitespace case
            var windowsWhitespaceResult = InvokePreparePath(_windowsService, "   ");
            var linuxWhitespaceResult = InvokePreparePath(_linuxService, "   ");
            Assert.AreEqual("   ", windowsWhitespaceResult, "Windows should handle whitespace");
            Assert.AreEqual("   ", linuxWhitespaceResult, "Linux should handle whitespace");
        }

        [TestMethod]
        public void PrepareFilePath_ShouldHandlePlatformSpecificEdgeCases()
        {
            // Test dash prefix (Linux specific)
            var dashPath = "-problematic.mp4";
            var windowsDashResult = InvokePreparePath(_windowsService, dashPath);
            var linuxDashResult = InvokePreparePath(_linuxService, dashPath);
            
            // Linux should prefix with underscore, Windows doesn't need to
            Assert.IsTrue(linuxDashResult.StartsWith("_"), "Linux should prefix dash-starting paths with underscore");

            // Test Windows reserved names
            var reservedPath = "CON.mp4";
            var windowsReservedResult = InvokePreparePath(_windowsService, reservedPath);
            var linuxReservedResult = InvokePreparePath(_linuxService, reservedPath);
            
            // Windows should prefix reserved names with underscore
            Assert.IsTrue(windowsReservedResult.StartsWith("_"), "Windows should prefix reserved names with underscore");

            // Test very long paths (Windows has stricter limits)
            var longPath = new string('a', 300) + ".mp4";
            var windowsLongResult = InvokePreparePath(_windowsService, longPath);
            var linuxLongResult = InvokePreparePath(_linuxService, longPath);
            
            // Windows should truncate, Linux might not need to
            Assert.IsTrue(windowsLongResult.Length <= 250, "Windows should truncate very long paths");
            Assert.IsTrue(windowsLongResult.EndsWith(".mp4"), "Windows should preserve extension when truncating");
        }

        [TestMethod]
        public void PrepareFilePath_ShouldMaintainFileExtensions()
        {
            // Arrange
            var pathsWithExtensions = new[]
            {
                "file.mp4",
                "file.avi",
                "file.mkv",
                "file.webm",
                "file with spaces.mp4",
                "file'with'quotes.avi"
            };

            foreach (var path in pathsWithExtensions)
            {
                // Act
                var windowsResult = InvokePreparePath(_windowsService, path);
                var linuxResult = InvokePreparePath(_linuxService, path);

                // Assert
                var originalExtension = System.IO.Path.GetExtension(path);
                Assert.IsTrue(windowsResult.EndsWith(originalExtension), $"Windows should preserve extension for: {path}");
                Assert.IsTrue(linuxResult.EndsWith(originalExtension), $"Linux should preserve extension for: {path}");
            }
        }

        private string InvokePreparePath(DownloadServiceBase service, string path)
        {
            return service.GetType()
                .GetMethod("PrepareFilePath", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .Invoke(service, new object[] { path }) as string;
        }
    }
}