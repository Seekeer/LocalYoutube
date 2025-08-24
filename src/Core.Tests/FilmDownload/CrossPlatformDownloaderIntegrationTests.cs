using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using API.FilmDownload;
using BookStore.Domain.Interfaces;
using FileStore.Domain;
using FileStore.Domain.Models;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using Moq;

namespace Core.Tests.FilmDownload
{
    /// <summary>
    /// Integration tests for cross-platform downloader functionality
    /// Tests that all downloaders work correctly on both Windows and Linux platforms
    /// </summary>
    public class CrossPlatformDownloaderIntegrationTests : IDisposable
    {
        private readonly ServiceProvider _serviceProvider;
        private readonly AppConfig _config;
        private readonly Mock<IPlatformDetectionService> _mockPlatformDetection;
        private readonly Mock<IScriptManager> _mockScriptManager;
        private readonly Mock<ILinuxDependencyManager> _mockLinuxDependencyManager;
        private readonly Mock<IDownloadLogger> _mockDownloadLogger;
        private readonly Mock<IErrorRecoveryService> _mockErrorRecoveryService;

        public CrossPlatformDownloaderIntegrationTests()
        {
            _config = new AppConfig
            {
                RootDownloadFolder = Path.GetTempPath(),
                UseProxy = false
            };

            _mockPlatformDetection = new Mock<IPlatformDetectionService>();
            _mockScriptManager = new Mock<IScriptManager>();
            _mockLinuxDependencyManager = new Mock<ILinuxDependencyManager>();
            _mockDownloadLogger = new Mock<IDownloadLogger>();
            _mockErrorRecoveryService = new Mock<IErrorRecoveryService>();

            // Setup script manager to return appropriate scripts for each platform
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Windows, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("PowerShell script content");
            _mockScriptManager.Setup(x => x.GetDownloadScript(OSPlatform.Linux, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("Bash script content");

            var services = new ServiceCollection();
            services.AddSingleton(_config);
            services.AddSingleton(_mockPlatformDetection.Object);
            services.AddSingleton(_mockScriptManager.Object);
            services.AddSingleton(_mockLinuxDependencyManager.Object);
            services.AddSingleton(_mockDownloadLogger.Object);
            services.AddSingleton(_mockErrorRecoveryService.Object);
            services.AddSingleton<IDownloadServiceFactory, DownloadServiceFactory>();

            _serviceProvider = services.BuildServiceProvider();
        }

        [Theory]
        [InlineData("https://www.youtube.com/watch?v=dQw4w9WgXcQ", typeof(YoutubeDownloader))]
        [InlineData("https://youtu.be/dQw4w9WgXcQ", typeof(YoutubeDownloader))]
        [InlineData("https://vk.com/video-123456_789012", typeof(VKDownloader))]
        [InlineData("https://vkvideo.ru/video-123456_789012", typeof(VKDownloader))]
        [InlineData("https://rossaprimavera.ru/video/test", typeof(RossaDownloader))]
        [InlineData("https://mishka-knizhka.ru/audio/test", typeof(MishkaDownloader))]
        [InlineData("https://example.com/video/test", typeof(CommonDownloader))]
        public void CreateDownloader_OnWindows_ShouldCreateCorrectDownloaderType(string url, Type expectedType)
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(url, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            Assert.IsType(expectedType, downloader);
            
            // Verify Windows download service was created
            _mockPlatformDetection.Verify(x => x.GetCurrentPlatform(), Times.AtLeastOnce);
        }

        [Theory]
        [InlineData("https://www.youtube.com/watch?v=dQw4w9WgXcQ", typeof(YoutubeDownloader))]
        [InlineData("https://youtu.be/dQw4w9WgXcQ", typeof(YoutubeDownloader))]
        [InlineData("https://vk.com/video-123456_789012", typeof(VKDownloader))]
        [InlineData("https://vkvideo.ru/video-123456_789012", typeof(VKDownloader))]
        [InlineData("https://rossaprimavera.ru/video/test", typeof(RossaDownloader))]
        [InlineData("https://mishka-knizhka.ru/audio/test", typeof(MishkaDownloader))]
        [InlineData("https://example.com/video/test", typeof(CommonDownloader))]
        public void CreateDownloader_OnLinux_ShouldCreateCorrectDownloaderType(string url, Type expectedType)
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Linux);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(url, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            Assert.IsType(expectedType, downloader);
            
            // Verify Linux download service was created
            _mockPlatformDetection.Verify(x => x.GetCurrentPlatform(), Times.AtLeastOnce);
        }

        [Fact]
        public void CreateDownloader_SwitchingPlatforms_ShouldCreateAppropriateServices()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";

            // Test Windows first
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);
            var windowsDownloader = DownloaderFabric.CreateDownloader(url, _config, factory);

            // Test Linux second
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Linux);
            var linuxDownloader = DownloaderFabric.CreateDownloader(url, _config, factory);

            // Assert
            Assert.NotNull(windowsDownloader);
            Assert.NotNull(linuxDownloader);
            Assert.IsType<YoutubeDownloader>(windowsDownloader);
            Assert.IsType<YoutubeDownloader>(linuxDownloader);
            
            // Both should be YoutubeDownloader but with different underlying download services
            _mockPlatformDetection.Verify(x => x.GetCurrentPlatform(), Times.AtLeast(2));
        }

        [Fact]
        public void CreateDownloader_WithProxyConfiguration_ShouldWorkOnBothPlatforms()
        {
            // Arrange
            var configWithProxy = new AppConfig
            {
                RootDownloadFolder = Path.GetTempPath(),
                UseProxy = true
            };

            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";

            // Test Windows with proxy
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);
            var windowsDownloader = DownloaderFabric.CreateDownloader(url, configWithProxy, factory);

            // Test Linux with proxy
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Linux);
            var linuxDownloader = DownloaderFabric.CreateDownloader(url, configWithProxy, factory);

            // Assert
            Assert.NotNull(windowsDownloader);
            Assert.NotNull(linuxDownloader);
            Assert.IsType<YoutubeDownloader>(windowsDownloader);
            Assert.IsType<YoutubeDownloader>(linuxDownloader);
        }

        [Theory]
        [InlineData("Windows")]
        [InlineData("Linux")]
        public void CreateDownloader_AllDownloaderTypes_ShouldWorkOnBothPlatforms(string platformName)
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var platform = platformName == "Windows" ? OSPlatform.Windows : OSPlatform.Linux;
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(platform);

            var testUrls = new[]
            {
                ("https://www.youtube.com/watch?v=dQw4w9WgXcQ", typeof(YoutubeDownloader)),
                ("https://vk.com/video-123456_789012", typeof(VKDownloader)),
                ("https://rossaprimavera.ru/video/test", typeof(RossaDownloader)),
                ("https://mishka-knizhka.ru/audio/test", typeof(MishkaDownloader)),
                ("https://example.com/video/test", typeof(CommonDownloader))
            };

            // Act & Assert
            foreach (var (url, expectedType) in testUrls)
            {
                var downloader = DownloaderFabric.CreateDownloader(url, _config, factory);
                
                Assert.NotNull(downloader);
                Assert.IsType(expectedType, downloader);
                
                // Verify downloader has correct properties
                Assert.True(downloader.DownloadType != DownloadType.Unknown);
                Assert.NotNull(downloader.DownloadType);
                
                downloader.Dispose();
            }
        }

        [Fact]
        public void CreateDownloader_WithDownloadTasks_ShouldWorkOnBothPlatforms()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            
            var tasks = new[]
            {
                new DownloadTask("https://www.youtube.com/watch?v=dQw4w9WgXcQ", null),
                new DownloadTask("https://vk.com/video-123456_789012", null),
                new DownloadTask("https://rossaprimavera.ru/video/test", null),
                new DownloadTask("https://mishka-knizhka.ru/audio/test", null),
                new DownloadTask("https://example.com/video/test", null)
            };

            // Test Windows
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);
            foreach (var task in tasks)
            {
                var windowsDownloader = DownloaderFabric.CreateDownloader(task, _config, factory);
                Assert.NotNull(windowsDownloader);
                Assert.True(DownloaderFabric.CanDownload(task, _config, factory));
                windowsDownloader.Dispose();
            }

            // Test Linux
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Linux);
            foreach (var task in tasks)
            {
                var linuxDownloader = DownloaderFabric.CreateDownloader(task, _config, factory);
                Assert.NotNull(linuxDownloader);
                Assert.True(DownloaderFabric.CanDownload(task, _config, factory));
                linuxDownloader.Dispose();
            }
        }

        [Fact]
        public void CreateDownloader_ErrorHandling_ShouldWorkOnBothPlatforms()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();

            // Test unsupported URLs on both platforms
            var unsupportedUrls = new[]
            {
                "https://rutracker.org/forum/viewtopic.php?t=123456",
                null,
                ""
            };

            foreach (var platform in new[] { OSPlatform.Windows, OSPlatform.Linux })
            {
                _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(platform);

                foreach (var url in unsupportedUrls)
                {
                    // Act
                    var downloader = DownloaderFabric.CreateDownloader(url, _config, factory);

                    // Assert
                    Assert.Null(downloader);

                    if (!string.IsNullOrEmpty(url))
                    {
                        var task = new DownloadTask(url, null);
                        Assert.False(DownloaderFabric.CanDownload(task, _config, factory));
                    }
                }
            }
        }

        public void Dispose()
        {
            _serviceProvider?.Dispose();
        }
    }
}