using API.FilmDownload;
using BookStore.Domain.Interfaces;
using FileStore.Domain;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;
using System;
using System.IO;
using System.Threading.Tasks;

namespace Core.Tests.FilmDownload
{
    [TestClass]
    public class DownloadServiceTests
    {
        private AppConfig _testConfig;
        private string _testAssetsPath;
        private Mock<IScriptManager> _mockScriptManager;

        [TestInitialize]
        public void Setup()
        {
            _testConfig = new AppConfig
            {
                UseProxy = false,
                RootDownloadFolder = Path.GetTempPath()
            };
            _mockScriptManager = new Mock<IScriptManager>();

            // Create test assets directory
            _testAssetsPath = Path.Combine(Directory.GetCurrentDirectory(), "Assets");
            if (!Directory.Exists(_testAssetsPath))
            {
                Directory.CreateDirectory(_testAssetsPath);
            }

            // Create a mock downloadScript.txt file for testing
            var mockScriptPath = Path.Combine(_testAssetsPath, "downloadScript.txt");
            if (!File.Exists(mockScriptPath))
            {
                File.WriteAllText(mockScriptPath, "# Mock download script for testing");
            }
        }

        [TestCleanup]
        public void Cleanup()
        {
            // Clean up test files if needed
            if (Directory.Exists(_testAssetsPath))
            {
                try
                {
                    var mockScriptPath = Path.Combine(_testAssetsPath, "downloadScript.txt");
                    if (File.Exists(mockScriptPath))
                    {
                        File.Delete(mockScriptPath);
                    }
                    Directory.Delete(_testAssetsPath);
                }
                catch
                {
                    // Ignore cleanup errors
                }
            }
        }

        [TestMethod]
        public void DownloadService_Constructor_ShouldInitializeWithConfig()
        {
            // Arrange & Act
            var downloadService = new DownloadService(_testConfig, _mockScriptManager.Object);

            // Assert
            Assert.IsNotNull(downloadService);
        }

        [TestMethod]
        public void WindowsDownloadService_Constructor_ShouldInitializeWithConfig()
        {
            // Arrange & Act
            var windowsDownloadService = new WindowsDownloadService(_testConfig, _mockScriptManager.Object);

            // Assert
            Assert.IsNotNull(windowsDownloadService);
        }

        [TestMethod]
        public void DownloadService_ShouldInheritFromWindowsDownloadService()
        {
            // Arrange & Act
            var downloadService = new DownloadService(_testConfig, _mockScriptManager.Object);

            // Assert
            Assert.IsInstanceOfType(downloadService, typeof(WindowsDownloadService));
            Assert.IsInstanceOfType(downloadService, typeof(DownloadServiceBase));
        }

        [TestMethod]
        public void WindowsDownloadService_ShouldInheritFromDownloadServiceBase()
        {
            // Arrange & Act
            var windowsDownloadService = new WindowsDownloadService(_testConfig, _mockScriptManager.Object);

            // Assert
            Assert.IsInstanceOfType(windowsDownloadService, typeof(DownloadServiceBase));
        }

        [TestMethod]
        public void DownloadServiceBase_PrepareFilePath_ShouldRemoveSpacesAndApostrophes()
        {
            // Arrange
            var downloadService = new TestableDownloadServiceBase(_testConfig);
            var inputPath = "test file with spaces and 'apostrophes'.mp4";
            var expectedPath = "testfilewithspacesandapostrophes.mp4";

            // Act
            var result = downloadService.TestPrepareFilePath(inputPath);

            // Assert
            Assert.AreEqual(expectedPath, result);
        }

        [TestMethod]
        public void DownloadServiceBase_PrepareFilePath_ShouldRemoveProblematicCharacters()
        {
            // Arrange
            var downloadService = new TestableDownloadServiceBase(_testConfig);
            var inputPath = "test:file*with?<>|chars\\and/quotes\t\n\r.mp4";

            // Act
            var result = downloadService.TestPrepareFilePath(inputPath);

            // Assert
            Assert.IsFalse(result.Contains(":"), "Colons should be replaced");
            Assert.IsFalse(result.Contains("*"), "Asterisks should be replaced");
            Assert.IsFalse(result.Contains("?"), "Question marks should be replaced");
            Assert.IsFalse(result.Contains("<"), "Less than should be replaced");
            Assert.IsFalse(result.Contains(">"), "Greater than should be replaced");
            Assert.IsFalse(result.Contains("|"), "Pipe should be replaced");
            Assert.IsFalse(result.Contains(" "), "Spaces should be removed");
            Assert.IsFalse(result.Contains("\t"), "Tabs should be removed");
            Assert.IsFalse(result.Contains("\n"), "Newlines should be removed");
            Assert.IsFalse(result.Contains("\r"), "Carriage returns should be removed");
            Assert.IsTrue(result.EndsWith(".mp4"), "Extension should be preserved");
        }

        [TestMethod]
        public void DownloadServiceBase_PrepareFilePath_ShouldHandleNullAndEmptyPaths()
        {
            // Arrange
            var downloadService = new TestableDownloadServiceBase(_testConfig);

            // Act & Assert for null
            var nullResult = downloadService.TestPrepareFilePath(null);
            Assert.IsNull(nullResult);

            // Act & Assert for empty string
            var emptyResult = downloadService.TestPrepareFilePath("");
            Assert.AreEqual("", emptyResult);

            // Act & Assert for whitespace
            var whitespaceResult = downloadService.TestPrepareFilePath("   ");
            Assert.AreEqual("   ", whitespaceResult);
        }

        [TestMethod]
        public void DownloadServiceBase_CleanUrl_ShouldRemoveListParameter()
        {
            // Arrange
            var downloadService = new TestableDownloadServiceBase(_testConfig);
            var inputUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLrAXtmRdnEQy";
            var expectedUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";

            // Act
            var result = downloadService.TestCleanUrl(inputUrl);

            // Assert
            Assert.AreEqual(expectedUrl, result);
        }

        [TestMethod]
        public void DownloadServiceBase_CleanUrl_ShouldReturnOriginalIfNoListParameter()
        {
            // Arrange
            var downloadService = new TestableDownloadServiceBase(_testConfig);
            var inputUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";

            // Act
            var result = downloadService.TestCleanUrl(inputUrl);

            // Assert
            Assert.AreEqual(inputUrl, result);
        }

        [TestMethod]
        public void DownloadServiceBase_HandleFileMoving_ShouldReturnTargetPathWhenFileExists()
        {
            // Arrange
            var downloadService = new TestableDownloadServiceBase(_testConfig);
            var tempFile = Path.GetTempFileName();
            var targetPath = Path.GetTempFileName();
            
            try
            {
                // Create a test file
                File.WriteAllText(tempFile, "test content");
                
                // Act
                var result = downloadService.TestHandleFileMoving(tempFile, targetPath);

                // Assert
                Assert.AreEqual(targetPath, result);
                Assert.IsTrue(File.Exists(targetPath));
                Assert.IsFalse(File.Exists(tempFile));
            }
            finally
            {
                // Cleanup
                if (File.Exists(tempFile)) File.Delete(tempFile);
                if (File.Exists(targetPath)) File.Delete(targetPath);
            }
        }

        [TestMethod]
        public void DownloadServiceBase_HandleFileMoving_ShouldTryHashSuffixWhenOriginalNotFound()
        {
            // Arrange
            var downloadService = new TestableDownloadServiceBase(_testConfig);
            var baseFileName = Path.GetTempFileName();
            var hashFileName = baseFileName + "#";
            var targetPath = Path.GetTempFileName();
            
            try
            {
                // Remove the base file and create the hash version
                File.Delete(baseFileName);
                File.WriteAllText(hashFileName, "test content");
                
                // Act
                var result = downloadService.TestHandleFileMoving(baseFileName, targetPath);

                // Assert
                Assert.AreEqual(targetPath, result);
                Assert.IsTrue(File.Exists(targetPath));
                Assert.IsFalse(File.Exists(hashFileName));
            }
            finally
            {
                // Cleanup
                if (File.Exists(baseFileName)) File.Delete(baseFileName);
                if (File.Exists(hashFileName)) File.Delete(hashFileName);
                if (File.Exists(targetPath)) File.Delete(targetPath);
            }
        }

        [TestMethod]
        public void ProxyManager_GetProxyString_ShouldReturnString()
        {
            // Act
            var result = ProxyManager.GetProxyString();

            // Assert
            Assert.IsNotNull(result);
            Assert.IsInstanceOfType(result, typeof(string));
        }

        // Helper class to test protected methods
        private class TestableDownloadServiceBase : DownloadServiceBase
        {
            public TestableDownloadServiceBase(AppConfig config) : base(config) { }

            public override Task<string> Download(string url, string path)
            {
                throw new NotImplementedException("This is a test class");
            }

            public string TestPrepareFilePath(string path) => PrepareFilePath(path);
            public string TestCleanUrl(string url) => CleanUrl(url);
            public string TestHandleFileMoving(string downloadedFileName, string targetPath) => HandleFileMoving(downloadedFileName, targetPath);
        }

        [TestMethod]
        public void DownloadService_ShouldMaintainBackwardCompatibility()
        {
            // Arrange
            var originalDownloadService = new DownloadService(_testConfig, _mockScriptManager.Object);
            var windowsDownloadService = new WindowsDownloadService(_testConfig, _mockScriptManager.Object);

            // Act & Assert - Both should have the same type hierarchy
            Assert.IsInstanceOfType(originalDownloadService, typeof(WindowsDownloadService));
            Assert.IsInstanceOfType(originalDownloadService, typeof(DownloadServiceBase));
            Assert.IsInstanceOfType(windowsDownloadService, typeof(DownloadServiceBase));
            
            // Both should implement the same interface
            Assert.IsInstanceOfType(originalDownloadService, typeof(IDownloadService));
            Assert.IsInstanceOfType(windowsDownloadService, typeof(IDownloadService));
        }

        [TestMethod]
        public void DownloadServiceBase_ShouldProvideCommonFunctionality()
        {
            // Arrange
            var testService = new TestableDownloadServiceBase(_testConfig);

            // Act & Assert - Test that common functionality is available
            var cleanedUrl = testService.TestCleanUrl("https://example.com/video?v=123&list=456");
            var preparedPath = testService.TestPrepareFilePath("test file with 'quotes'.mp4");

            Assert.AreEqual("https://example.com/video?v=123", cleanedUrl);
            Assert.AreEqual("testfilewithquotes.mp4", preparedPath);
        }

        [TestMethod]
        public void WindowsDownloadService_ShouldInheritCommonFunctionality()
        {
            // Arrange
            var windowsService = new WindowsDownloadService(_testConfig, _mockScriptManager.Object);

            // Act & Assert - Verify it's properly inheriting from base
            Assert.IsInstanceOfType(windowsService, typeof(DownloadServiceBase));
            Assert.IsInstanceOfType(windowsService, typeof(IDownloadService));
            
            // Verify it has the Download method
            var downloadMethod = windowsService.GetType().GetMethod("Download");
            Assert.IsNotNull(downloadMethod);
            Assert.AreEqual(typeof(Task<string>), downloadMethod.ReturnType);
        }
    }
}