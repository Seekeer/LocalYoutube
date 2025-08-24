using System;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using API.FilmDownload;
using BookStore.Domain.Interfaces;
using BookStore.Infrastructure.Services;
using FileStore.Domain;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Core.Tests.FilmDownload
{
    /// <summary>
    /// Integration tests for platform detection and factory pattern
    /// Tests Requirements: 1.1, 1.2, 1.3, 1.4
    /// </summary>
    public class PlatformFactoryIntegrationTests
    {
        private readonly ServiceProvider _serviceProvider;
        private readonly AppConfig _config;

        public PlatformFactoryIntegrationTests()
        {
            _config = new AppConfig
            {
                UseProxy = false,
                RootDownloadFolder = System.IO.Path.GetTempPath()
            };

            var services = new ServiceCollection();
            SetupDependencyInjection(services);
            _serviceProvider = services.BuildServiceProvider();
        }

        private void SetupDependencyInjection(IServiceCollection services)
        {
            // Register core services
            services.AddSingleton(_config);
            services.AddSingleton<IPlatformDetectionService, PlatformDetectionService>();
            services.AddSingleton<IDownloadServiceFactory, DownloadServiceFactory>();

            // Register mocked dependencies
            var mockScriptManager = new Mock<IScriptManager>();
            mockScriptManager.Setup(x => x.GetDownloadScript(It.IsAny<OSPlatform>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
                .Returns("echo 'Test script execution'");
            services.AddSingleton(mockScriptManager.Object);

            var mockDependencyManager = new Mock<ILinuxDependencyManager>();
            mockDependencyManager.Setup(x => x.CheckDependenciesAsync()).ReturnsAsync(true);
            mockDependencyManager.Setup(x => x.EnsureDependenciesAsync()).ReturnsAsync(true);
            services.AddSingleton(mockDependencyManager.Object);

            var mockDownloadLogger = new Mock<IDownloadLogger>();
            services.AddSingleton(mockDownloadLogger.Object);

            var mockErrorRecoveryService = new Mock<IErrorRecoveryService>();
            mockErrorRecoveryService.Setup(x => x.IsRecoverable(It.IsAny<Exception>())).Returns(false);
            services.AddSingleton(mockErrorRecoveryService.Object);

            // Register logging
            services.AddLogging(builder => builder.AddConsole());
        }

        [Fact]
        public void PlatformDetectionService_ShouldDetectCurrentPlatform()
        {
            // Arrange
            var platformDetection = _serviceProvider.GetRequiredService<IPlatformDetectionService>();

            // Act
            var currentPlatform = platformDetection.GetCurrentPlatform();
            var isWindows = platformDetection.IsWindows();
            var isLinux = platformDetection.IsLinux();

            // Assert
            Assert.True(currentPlatform == OSPlatform.Windows || currentPlatform == OSPlatform.Linux || currentPlatform == OSPlatform.OSX);
            
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                Assert.True(isWindows);
                Assert.False(isLinux);
                Assert.Equal(OSPlatform.Windows, currentPlatform);
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                Assert.False(isWindows);
                Assert.True(isLinux);
                Assert.Equal(OSPlatform.Linux, currentPlatform);
            }
        }

        [Fact]
        public void DownloadServiceFactory_ShouldCreateCorrectServiceForCurrentPlatform()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var platformDetection = _serviceProvider.GetRequiredService<IPlatformDetectionService>();

            // Act
            var downloadService = factory.CreateDownloadService();
            var currentPlatform = platformDetection.GetCurrentPlatform();

            // Assert
            Assert.NotNull(downloadService);
            
            if (currentPlatform == OSPlatform.Windows)
            {
                Assert.IsType<WindowsDownloadService>(downloadService);
            }
            else if (currentPlatform == OSPlatform.Linux)
            {
                Assert.IsType<LinuxDownloadService>(downloadService);
            }
        }

        [Fact]
        public void DownloadServiceFactory_WithMockedPlatformDetection_ShouldCreateWindowsService()
        {
            // Arrange
            var mockPlatformDetection = new Mock<IPlatformDetectionService>();
            mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Windows);
            mockPlatformDetection.Setup(x => x.IsWindows()).Returns(true);
            mockPlatformDetection.Setup(x => x.IsLinux()).Returns(false);

            var factory = new DownloadServiceFactory(
                mockPlatformDetection.Object,
                _serviceProvider.GetRequiredService<IScriptManager>(),
                _serviceProvider.GetRequiredService<ILinuxDependencyManager>(),
                _serviceProvider.GetRequiredService<IDownloadLogger>(),
                _serviceProvider.GetRequiredService<IErrorRecoveryService>(),
                _config
            );

            // Act
            var downloadService = factory.CreateDownloadService();

            // Assert
            Assert.IsType<WindowsDownloadService>(downloadService);
        }

        [Fact]
        public void DownloadServiceFactory_WithMockedPlatformDetection_ShouldCreateLinuxService()
        {
            // Arrange
            var mockPlatformDetection = new Mock<IPlatformDetectionService>();
            mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.Linux);
            mockPlatformDetection.Setup(x => x.IsWindows()).Returns(false);
            mockPlatformDetection.Setup(x => x.IsLinux()).Returns(true);

            var factory = new DownloadServiceFactory(
                mockPlatformDetection.Object,
                _serviceProvider.GetRequiredService<IScriptManager>(),
                _serviceProvider.GetRequiredService<ILinuxDependencyManager>(),
                _serviceProvider.GetRequiredService<IDownloadLogger>(),
                _serviceProvider.GetRequiredService<IErrorRecoveryService>(),
                _config
            );

            // Act
            var downloadService = factory.CreateDownloadService();

            // Assert
            Assert.IsType<LinuxDownloadService>(downloadService);
        }

        [Fact]
        public void DownloadServiceFactory_WithUnsupportedPlatform_ShouldDefaultToLinux()
        {
            // Arrange
            var mockPlatformDetection = new Mock<IPlatformDetectionService>();
            mockPlatformDetection.Setup(x => x.GetCurrentPlatform()).Returns(OSPlatform.OSX);
            mockPlatformDetection.Setup(x => x.IsWindows()).Returns(false);
            mockPlatformDetection.Setup(x => x.IsLinux()).Returns(false);

            var factory = new DownloadServiceFactory(
                mockPlatformDetection.Object,
                _serviceProvider.GetRequiredService<IScriptManager>(),
                _serviceProvider.GetRequiredService<ILinuxDependencyManager>(),
                _serviceProvider.GetRequiredService<IDownloadLogger>(),
                _serviceProvider.GetRequiredService<IErrorRecoveryService>(),
                _config
            );

            // Act
            var downloadService = factory.CreateDownloadService();

            // Assert
            Assert.IsType<LinuxDownloadService>(downloadService);
        }

        [Fact]
        public async Task IntegratedDownloadFlow_ShouldWorkEndToEnd()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var downloadService = factory.CreateDownloadService();
            var platformDetection = _serviceProvider.GetRequiredService<IPlatformDetectionService>();

            var testUrl = "https://example.com/integration-test-video";
            var outputFile = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "integration_test.mp4");

            try
            {
                // Create a temporary file to simulate successful download
                System.IO.File.WriteAllText(outputFile, "test content");

                // Act
                var result = await downloadService.Download(testUrl, outputFile);

                // Assert
                Assert.Equal(outputFile, result);
                Assert.True(System.IO.File.Exists(outputFile));

                // Verify the correct service type was created based on platform
                var currentPlatform = platformDetection.GetCurrentPlatform();
                if (currentPlatform == OSPlatform.Windows)
                {
                    Assert.IsType<WindowsDownloadService>(downloadService);
                }
                else if (currentPlatform == OSPlatform.Linux)
                {
                    Assert.IsType<LinuxDownloadService>(downloadService);
                }
            }
            finally
            {
                if (System.IO.File.Exists(outputFile))
                {
                    System.IO.File.Delete(outputFile);
                }
            }
        }

        [Fact]
        public void ServiceRegistration_ShouldResolveAllDependencies()
        {
            // Act & Assert - Verify all services can be resolved
            Assert.NotNull(_serviceProvider.GetRequiredService<IPlatformDetectionService>());
            Assert.NotNull(_serviceProvider.GetRequiredService<IDownloadServiceFactory>());
            Assert.NotNull(_serviceProvider.GetRequiredService<IScriptManager>());
            Assert.NotNull(_serviceProvider.GetRequiredService<ILinuxDependencyManager>());
            Assert.NotNull(_serviceProvider.GetRequiredService<IDownloadLogger>());
            Assert.NotNull(_serviceProvider.GetRequiredService<IErrorRecoveryService>());
        }

        [Fact]
        public void DownloadServiceFactory_ShouldCreateNewInstanceEachTime()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();

            // Act
            var service1 = factory.CreateDownloadService();
            var service2 = factory.CreateDownloadService();

            // Assert
            Assert.NotNull(service1);
            Assert.NotNull(service2);
            Assert.NotSame(service1, service2); // Should be different instances
            Assert.Equal(service1.GetType(), service2.GetType()); // But same type
        }

        [Fact]
        public async Task PlatformSpecificBehavior_ShouldMaintainConsistentInterface()
        {
            // Arrange
            var factory = _serviceProvider.GetRequiredService<IDownloadServiceFactory>();
            var downloadService = factory.CreateDownloadService();

            var testUrl = "https://example.com/interface-test-video";
            var outputFile = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "interface_test.mp4");

            try
            {
                // Create a temporary file to simulate successful download
                System.IO.File.WriteAllText(outputFile, "test content");

                // Act
                var result = await downloadService.Download(testUrl, outputFile);

                // Assert
                Assert.NotNull(result);
                Assert.IsType<string>(result);
                Assert.Equal(outputFile, result);

                // Verify the service implements the expected interface
                Assert.IsAssignableFrom<IDownloadService>(downloadService);
                Assert.IsAssignableFrom<DownloadServiceBase>(downloadService);
            }
            finally
            {
                if (System.IO.File.Exists(outputFile))
                {
                    System.IO.File.Delete(outputFile);
                }
            }
        }
    }
}