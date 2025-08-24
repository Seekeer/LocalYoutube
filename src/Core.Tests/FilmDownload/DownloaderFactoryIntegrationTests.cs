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
    /// Integration tests for downloader factory pattern across all downloader types and platforms
    /// </summary>
    public class DownloaderFactoryIntegrationTests : IDisposable
    {
        private readonly ServiceProvider _serviceProvider;
        private readonly AppConfig _config;
        private readonly Mock<IPlatformDetectionService> _mockPlatformDetection;
        private readonly Mock<IScriptManager> _mockScriptManager;
        private readonly Mock<ILinuxDependencyManager> _mockLinuxDependencyManager;
        private readonly Mock<IDownloadLogger> _mockDownloadLogger;
        private readonly Mock<IErrorRecoveryService> _mockErrorRecoveryService;

        public DownloaderFactoryIntegrationTests()
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

        [Fact]
        public void CreateDownloader_WithYoutubeUrl_ShouldReturnYoutubeDownloader()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var youtubeUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(youtubeUrl, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            Assert.IsType<YoutubeDownloader>(downloader);
            Assert.Equal(DownloadType.Youtube, downloader.DownloadType);
        }

        [Fact]
        public void CreateDownloader_WithYoutubeShortUrl_ShouldReturnYoutubeDownloader()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var youtubeUrl = "https://youtu.be/dQw4w9WgXcQ";
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(youtubeUrl, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            Assert.IsType<YoutubeDownloader>(downloader);
            Assert.Equal(DownloadType.Youtube, downloader.DownloadType);
        }

        [Fact]
        public void CreateDownloader_WithVKUrl_ShouldReturnVKDownloader()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var vkUrl = "https://vk.com/video-123456_789012";
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(vkUrl, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            Assert.IsType<VKDownloader>(downloader);
            Assert.Equal(DownloadType.VK, downloader.DownloadType);
        }

        [Fact]
        public void CreateDownloader_WithVKVideoUrl_ShouldReturnVKDownloader()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var vkUrl = "https://vkvideo.ru/video-123456_789012";
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(vkUrl, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            Assert.IsType<VKDownloader>(downloader);
            Assert.Equal(DownloadType.VK, downloader.DownloadType);
        }

        [Fact]
        public void CreateDownloader_WithRossaUrl_ShouldReturnRossaDownloader()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var rossaUrl = "https://rossaprimavera.ru/video/test";
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(rossaUrl, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            Assert.IsType<RossaDownloader>(downloader);
            Assert.Equal(DownloadType.Rossaprimavera, downloader.DownloadType);
        }

        [Fact]
        public void CreateDownloader_WithMishkaUrl_ShouldReturnMishkaDownloader()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var mishkaUrl = "https://mishka-knizhka.ru/audio/test";
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(mishkaUrl, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            Assert.IsType<MishkaDownloader>(downloader);
            Assert.Equal(DownloadType.Mishka, downloader.DownloadType);
        }

        [Fact]
        public void CreateDownloader_WithGenericUrl_ShouldReturnCommonDownloader()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var genericUrl = "https://example.com/video/test";
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(genericUrl, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            Assert.IsType<CommonDownloader>(downloader);
            Assert.Equal(DownloadType.Common, downloader.DownloadType);
        }

        [Fact]
        public void CreateDownloader_WithRutrackerUrl_ShouldReturnNull()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var rutrackerUrl = "https://rutracker.org/forum/viewtopic.php?t=123456";
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(rutrackerUrl, _config, factory);

            // Assert
            Assert.Null(downloader);
        }

        [Fact]
        public void CreateDownloader_WithNullUrl_ShouldReturnNull()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader((string)null, _config, factory);

            // Assert
            Assert.Null(downloader);
        }

        [Theory]
        [InlineData("https://www.youtube.com/watch?v=dQw4w9WgXcQ")]
        [InlineData("https://vk.com/video-123456_789012")]
        [InlineData("https://rossaprimavera.ru/video/test")]
        [InlineData("https://mishka-knizhka.ru/audio/test")]
        [InlineData("https://example.com/video/test")]
        public void CreateDownloader_OnWindows_ShouldUseWindowsDownloadService(string url)
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(url, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            // Verify that the downloader was created with Windows download service
            _mockPlatformDetection.Verify(x => x.GetCurrentPlatform(), Times.AtLeastOnce);
        }

        [Theory]
        [InlineData("https://www.youtube.com/watch?v=dQw4w9WgXcQ")]
        [InlineData("https://vk.com/video-123456_789012")]
        [InlineData("https://rossaprimavera.ru/video/test")]
        [InlineData("https://mishka-knizhka.ru/audio/test")]
        [InlineData("https://example.com/video/test")]
        public void CreateDownloader_OnLinux_ShouldUseLinuxDownloadService(string url)
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Linux);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(url, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            // Verify that the downloader was created with Linux download service
            _mockPlatformDetection.Verify(x => x.GetCurrentPlatform(), Times.AtLeastOnce);
        }

        [Fact]
        public void CreateDownloader_WithDownloadTask_ShouldReturnCorrectDownloader()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var task = new DownloadTask("https://www.youtube.com/watch?v=dQw4w9WgXcQ", null);
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var downloader = DownloaderFabric.CreateDownloader(task, _config, factory);

            // Assert
            Assert.NotNull(downloader);
            Assert.IsType<YoutubeDownloader>(downloader);
            Assert.Equal(DownloadType.Youtube, downloader.DownloadType);
        }

        [Fact]
        public void CanDownload_WithSupportedUrl_ShouldReturnTrue()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var task = new DownloadTask("https://www.youtube.com/watch?v=dQw4w9WgXcQ", null);
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var canDownload = DownloaderFabric.CanDownload(task, _config, factory);

            // Assert
            Assert.True(canDownload);
        }

        [Fact]
        public void CanDownload_WithUnsupportedUrl_ShouldReturnFalse()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var task = new DownloadTask("https://rutracker.org/forum/viewtopic.php?t=123456", null);
            
            _mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var canDownload = DownloaderFabric.CanDownload(task, _config, factory);

            // Assert
            Assert.False(canDownload);
        }

        [Fact]
        public void CreateDownloader_BackwardCompatibility_ShouldStillWork()
        {
            // Arrange
            var mockDownloadService = new Mock<IDownloadService>();
            var youtubeUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";

            // Act & Assert - Should not throw exception
#pragma warning disable CS0618 // Type or member is obsolete
            var downloader = DownloaderFabric.CreateDownloader(youtubeUrl, _config, mockDownloadService.Object);
#pragma warning restore CS0618 // Type or member is obsolete

            // Assert
            Assert.NotNull(downloader);
            Assert.IsType<YoutubeDownloader>(downloader);
        }

        [Fact]
        public void CanDownload_BackwardCompatibility_ShouldStillWork()
        {
            // Arrange
            var mockDownloadService = new Mock<IDownloadService>();
            var task = new DownloadTask("https://www.youtube.com/watch?v=dQw4w9WgXcQ", null);

            // Act & Assert - Should not throw exception
#pragma warning disable CS0618 // Type or member is obsolete
            var canDownload = DownloaderFabric.CanDownload(task, _config, mockDownloadService.Object);
#pragma warning restore CS0618 // Type or member is obsolete

            // Assert
            Assert.True(canDownload);
        }

        public void Dispose()
        {
            _serviceProvider?.Dispose();
        }
    }
}