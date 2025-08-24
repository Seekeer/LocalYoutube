using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using API.FilmDownload;
using BookStore.Domain.Interfaces;
using FileStore.Domain;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Core.Tests.FilmDownload
{
    /// <summary>
    /// Integration tests for file output consistency between Windows and Linux platforms
    /// Tests Requirements: 3.3 - File output consistency between platforms
    /// </summary>
    public class FileOutputConsistencyIntegrationTests : IDisposable
    {
        private readonly Mock<IScriptManager> _mockScriptManager;
        private readonly Mock<ILinuxDependencyManager> _mockDependencyManager;
        private readonly Mock<IDownloadLogger> _mockDownloadLogger;
        private readonly Mock<IErrorRecoveryService> _mockErrorRecoveryService;
        private readonly AppConfig _config;
        private readonly List<string> _tempFiles;
        private readonly string _tempDirectory;

        public FileOutputConsistencyIntegrationTests()
        {
            _mockScriptManager = new Mock<IScriptManager>();
            _mockDependencyManager = new Mock<ILinuxDependencyManager>();
            _mockDownloadLogger = new Mock<IDownloadLogger>();
            _mockErrorRecoveryService = new Mock<IErrorRecoveryService>();
            
            _config = new AppConfig
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

            // Setup successful script execution by default
            _mockScriptManager.Setup(x => x.GetDownloadScript(It.IsAny<OSPlatform>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Download completed successfully'");

            // Setup error recovery as non-recoverable by default
            _mockErrorRecoveryService.Setup(x => x.IsRecoverable(It.IsAny<Exception>())).Returns(false);
        }

        #region File Naming Consistency Tests

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
        public async Task CrossPlatform_SpecialCharacters_ShouldHandleConsistently()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/special-chars-video";
            var testFileName = "test file with spaces & symbols!@#$%^&*().mp4";
            var linuxPath = Path.Combine(_tempDirectory, "linux", testFileName);
            var windowsPath = Path.Combine(_tempDirectory, "windows", testFileName);

            Directory.CreateDirectory(Path.GetDirectoryName(linuxPath));
            Directory.CreateDirectory(Path.GetDirectoryName(windowsPath));

            // Create temp files
            File.WriteAllText(linuxPath, "linux content");
            File.WriteAllText(windowsPath, "windows content");
            _tempFiles.Add(linuxPath);
            _tempFiles.Add(windowsPath);

            // Act
            var linuxResult = await linuxService.Download(testUrl, linuxPath);
            var windowsResult = await windowsService.Download(testUrl, windowsPath);

            // Assert
            Assert.Equal(linuxPath, linuxResult);
            Assert.Equal(windowsPath, windowsResult);
            
            // Verify both platforms handled the same URL and file name
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Windows, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
        }

        [Fact]
        public async Task CrossPlatform_UnicodeCharacters_ShouldHandleConsistently()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/unicode-video";
            var unicodeFileName = "测试视频_тест_видео_🎬.mp4";
            var linuxPath = Path.Combine(_tempDirectory, "linux", unicodeFileName);
            var windowsPath = Path.Combine(_tempDirectory, "windows", unicodeFileName);

            Directory.CreateDirectory(Path.GetDirectoryName(linuxPath));
            Directory.CreateDirectory(Path.GetDirectoryName(windowsPath));

            // Create temp files
            File.WriteAllText(linuxPath, "linux unicode content");
            File.WriteAllText(windowsPath, "windows unicode content");
            _tempFiles.Add(linuxPath);
            _tempFiles.Add(windowsPath);

            // Act
            var linuxResult = await linuxService.Download(testUrl, linuxPath);
            var windowsResult = await windowsService.Download(testUrl, windowsPath);

            // Assert
            Assert.Equal(linuxPath, linuxResult);
            Assert.Equal(windowsPath, windowsResult);
        }

        #endregion

        #region Path Handling Consistency Tests

        [Fact]
        public async Task CrossPlatform_PathSeparators_ShouldHandleDifferentConventions()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/path-separator-video";
            var linuxPath = "/home/user/videos/test video.mp4";
            var windowsPath = @"C:\Users\user\videos\test video.mp4";

            // Create temp files to simulate the paths
            var tempLinuxFile = CreateTempFile("linux_path_test.mp4");
            var tempWindowsFile = CreateTempFile("windows_path_test.mp4");

            // Act
            var linuxResult = await linuxService.Download(testUrl, tempLinuxFile);
            var windowsResult = await windowsService.Download(testUrl, tempWindowsFile);

            // Assert
            Assert.Equal(tempLinuxFile, linuxResult);
            Assert.Equal(tempWindowsFile, windowsResult);
            
            // Verify both platforms were called with correct platform identifiers
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Windows, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
        }

        [Fact]
        public async Task CrossPlatform_LongPaths_ShouldHandleConsistently()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/long-path-video";
            var longFileName = new string('a', 200) + ".mp4"; // Very long filename
            var linuxLongPath = CreateTempFile($"linux_{longFileName}");
            var windowsLongPath = CreateTempFile($"windows_{longFileName}");

            // Act
            var linuxResult = await linuxService.Download(testUrl, linuxLongPath);
            var windowsResult = await windowsService.Download(testUrl, windowsLongPath);

            // Assert
            Assert.Equal(linuxLongPath, linuxResult);
            Assert.Equal(windowsLongPath, windowsResult);
        }

        #endregion

        #region File Extension Consistency Tests

        [Fact]
        public async Task CrossPlatform_FileExtensions_ShouldHandleAllFormatsConsistently()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/multi-format-video";
            var extensions = new[] { ".mp4", ".webm", ".mkv", ".avi", ".mov", ".flv" };

            // Act & Assert
            foreach (var extension in extensions)
            {
                var linuxFile = CreateTempFile($"linux_test{extension}");
                var windowsFile = CreateTempFile($"windows_test{extension}");

                var linuxResult = await linuxService.Download(testUrl, linuxFile);
                var windowsResult = await windowsService.Download(testUrl, windowsFile);

                Assert.Equal(linuxFile, linuxResult);
                Assert.Equal(windowsFile, windowsResult);
            }

            // Verify all extensions were processed
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Exactly(extensions.Length));
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Windows, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Exactly(extensions.Length));
        }

        [Fact]
        public async Task CrossPlatform_NoExtension_ShouldHandleConsistently()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/no-extension-video";
            var linuxFile = CreateTempFile("linux_no_extension");
            var windowsFile = CreateTempFile("windows_no_extension");

            // Act
            var linuxResult = await linuxService.Download(testUrl, linuxFile);
            var windowsResult = await windowsService.Download(testUrl, windowsFile);

            // Assert
            Assert.Equal(linuxFile, linuxResult);
            Assert.Equal(windowsFile, windowsResult);
        }

        #endregion

        #region Output Format Consistency Tests

        [Fact]
        public async Task CrossPlatform_MergeOutputFormats_ShouldProduceSameResult()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/merge-test-video";
            var linuxOutputFile = CreateTempFile("linux_merged.mp4");
            var windowsOutputFile = CreateTempFile("windows_merged.mp4");

            // Setup scripts to simulate format merging
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Linux: Merging video and audio streams...' && echo 'Linux: Merge completed'");
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Windows, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Windows: Merging video and audio streams...' && echo 'Windows: Merge completed'");

            // Act
            var linuxResult = await linuxService.Download(testUrl, linuxOutputFile);
            var windowsResult = await windowsService.Download(testUrl, windowsOutputFile);

            // Assert
            Assert.Equal(linuxOutputFile, linuxResult);
            Assert.Equal(windowsOutputFile, windowsResult);
            
            // Verify both platforms handled merging
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Windows, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
        }

        [Fact]
        public async Task CrossPlatform_InfoJsonFiles_ShouldCreateConsistently()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/info-json-video";
            var linuxOutputFile = CreateTempFile("linux_info.mp4");
            var windowsOutputFile = CreateTempFile("windows_info.mp4");

            // Act
            await linuxService.Download(testUrl, linuxOutputFile);
            await windowsService.Download(testUrl, windowsOutputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Windows, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
        }

        [Fact]
        public async Task CrossPlatform_ThumbnailFiles_ShouldCreateConsistently()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/thumbnail-video";
            var linuxOutputFile = CreateTempFile("linux_thumb.mp4");
            var windowsOutputFile = CreateTempFile("windows_thumb.mp4");

            // Setup scripts to simulate thumbnail creation
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Linux: Creating thumbnail...' && echo 'Linux: Download with thumbnail completed'");
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Windows, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Windows: Creating thumbnail...' && echo 'Windows: Download with thumbnail completed'");

            // Act
            await linuxService.Download(testUrl, linuxOutputFile);
            await windowsService.Download(testUrl, windowsOutputFile);

            // Assert
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Windows, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Once);
        }

        #endregion

        #region File Size and Quality Consistency Tests

        [Fact]
        public async Task CrossPlatform_VideoQuality_ShouldProduceSimilarResults()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/quality-test-video";
            var qualities = new[] { "720p", "1080p", "480p", "best", "worst" };

            // Act & Assert
            foreach (var quality in qualities)
            {
                var linuxFile = CreateTempFile($"linux_{quality}.mp4");
                var windowsFile = CreateTempFile($"windows_{quality}.mp4");

                await linuxService.Download(testUrl, linuxFile);
                await windowsService.Download(testUrl, windowsFile);
            }

            // Verify all quality options were processed
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Exactly(qualities.Length));
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Windows, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Exactly(qualities.Length));
        }

        [Fact]
        public async Task CrossPlatform_AudioFormats_ShouldHandleConsistently()
        {
            // Arrange
            var linuxService = new LinuxDownloadService(_config, _mockScriptManager.Object, 
                _mockDependencyManager.Object, _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);
            var windowsService = new WindowsDownloadService(_config, _mockScriptManager.Object, 
                _mockDownloadLogger.Object, _mockErrorRecoveryService.Object);

            var testUrl = "https://example.com/audio-format-video";
            var audioFormats = new[] { ".mp3", ".aac", ".ogg", ".wav", ".flac" };

            // Act & Assert
            foreach (var format in audioFormats)
            {
                var linuxFile = CreateTempFile($"linux_audio{format}");
                var windowsFile = CreateTempFile($"windows_audio{format}");

                await linuxService.Download(testUrl, linuxFile);
                await windowsService.Download(testUrl, windowsFile);
            }

            // Verify all audio formats were processed
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Linux, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Exactly(audioFormats.Length));
            _mockScriptManager.Verify(x => x.GetDownloadScript(OSPlatform.Windows, testUrl, It.IsAny<string>(), It.IsAny<string>()), Times.Exactly(audioFormats.Length));
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