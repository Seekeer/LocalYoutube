using System;
using System.Runtime.InteropServices;
using API.FilmDownload;
using BookStore.Domain.Interfaces;
using FileStore.Domain;
using Moq;
using Xunit;

namespace Core.Tests.Infrastructure
{
    /// <summary>
    /// Unit tests for DownloadServiceFactory
    /// </summary>
    public class DownloadServiceFactoryTests
    {
        private readonly Mock<IPlatformDetectionService> _mockPlatformDetectionService;
        private readonly Mock<IScriptManager> _mockScriptManager;
        private readonly Mock<ILinuxDependencyManager> _mockLinuxDependencyManager;
        private readonly DownloadServiceFactory _factory;
        private readonly AppConfig _testConfig;

        public DownloadServiceFactoryTests()
        {
            _mockPlatformDetectionService = new Mock<IPlatformDetectionService>();
            _mockScriptManager = new Mock<IScriptManager>();
            _mockLinuxDependencyManager = new Mock<ILinuxDependencyManager>();
            _factory = new DownloadServiceFactory(_mockPlatformDetectionService.Object, _mockScriptManager.Object, _mockLinuxDependencyManager.Object);
            _testConfig = new AppConfig
            {
                UseProxy = false,
                RootDownloadFolder = "test"
            };
        }

        [Fact]
        public void Constructor_WithNullPlatformDetectionService_ThrowsArgumentNullException()
        {
            // Act & Assert
            Assert.Throws<ArgumentNullException>(() => new DownloadServiceFactory(null, _mockScriptManager.Object, _mockLinuxDependencyManager.Object));
        }

        [Fact]
        public void Constructor_WithNullScriptManager_ThrowsArgumentNullException()
        {
            // Act & Assert
            Assert.Throws<ArgumentNullException>(() => new DownloadServiceFactory(_mockPlatformDetectionService.Object, null, _mockLinuxDependencyManager.Object));
        }

        [Fact]
        public void Constructor_WithNullLinuxDependencyManager_ThrowsArgumentNullException()
        {
            // Act & Assert
            Assert.Throws<ArgumentNullException>(() => new DownloadServiceFactory(_mockPlatformDetectionService.Object, _mockScriptManager.Object, null));
        }

        [Fact]
        public void CreateDownloadService_WithNullConfig_ThrowsArgumentNullException()
        {
            // Arrange
            _mockPlatformDetectionService.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act & Assert
            Assert.Throws<ArgumentNullException>(() => _factory.CreateDownloadService(null));
        }

        [Fact]
        public void CreateDownloadService_OnWindows_ReturnsWindowsDownloadService()
        {
            // Arrange
            _mockPlatformDetectionService.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            var result = _factory.CreateDownloadService(_testConfig);

            // Assert
            Assert.NotNull(result);
            Assert.IsType<WindowsDownloadService>(result);
        }

        [Fact]
        public void CreateDownloadService_OnLinux_ReturnsLinuxDownloadService()
        {
            // Arrange
            _mockPlatformDetectionService.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Linux);

            // Act
            var result = _factory.CreateDownloadService(_testConfig);

            // Assert
            Assert.NotNull(result);
            Assert.IsType<LinuxDownloadService>(result);
        }

        [Fact]
        public void CreateDownloadService_OnOSX_ThrowsPlatformNotSupportedException()
        {
            // Arrange
            _mockPlatformDetectionService.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.OSX);

            // Act & Assert
            var exception = Assert.Throws<PlatformNotSupportedException>(() => _factory.CreateDownloadService(_testConfig));
            Assert.Contains("Platform OSX is not supported", exception.Message);
        }

        [Fact]
        public void CreateDownloadService_OnFreeBSD_ThrowsPlatformNotSupportedException()
        {
            // Arrange
            _mockPlatformDetectionService.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.FreeBSD);

            // Act & Assert
            var exception = Assert.Throws<PlatformNotSupportedException>(() => _factory.CreateDownloadService(_testConfig));
            Assert.Contains("Platform FREEBSD is not supported", exception.Message);
        }

        [Fact]
        public void CreateDownloadService_WithValidConfig_PassesConfigToDownloadService()
        {
            // Arrange
            _mockPlatformDetectionService.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);
            var configWithProxy = new AppConfig
            {
                UseProxy = true,
                RootDownloadFolder = "test-with-proxy"
            };

            // Act
            var result = _factory.CreateDownloadService(configWithProxy);

            // Assert
            Assert.NotNull(result);
            Assert.IsType<WindowsDownloadService>(result);
            // Note: We can't directly test that the config was passed correctly without exposing internal state
            // This would be better tested through integration tests
        }

        [Fact]
        public void CreateDownloadService_CallsPlatformDetectionService()
        {
            // Arrange
            _mockPlatformDetectionService.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);

            // Act
            _factory.CreateDownloadService(_testConfig);

            // Assert
            _mockPlatformDetectionService.Verify(x => x.GetCurrentPlatform(), Times.Once);
        }
    }
}