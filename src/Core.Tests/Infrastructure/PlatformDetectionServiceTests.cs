using System.Runtime.InteropServices;
using BookStore.Infrastructure.Services;
using NUnit.Framework;

namespace Core.Tests.Infrastructure
{
    [TestFixture]
    public class PlatformDetectionServiceTests
    {
        private PlatformDetectionService _platformDetectionService;

        [SetUp]
        public void Setup()
        {
            _platformDetectionService = new PlatformDetectionService();
        }

        [Test]
        public void GetCurrentPlatform_ShouldReturnValidPlatform()
        {
            // Act
            var result = _platformDetectionService.GetCurrentPlatform();

            // Assert
            Assert.That(result, Is.Not.Null);
            Assert.That(result, Is.AnyOf(OSPlatform.Windows, OSPlatform.Linux, OSPlatform.OSX));
        }

        [Test]
        public void IsWindows_ShouldReturnConsistentResult()
        {
            // Act
            var result1 = _platformDetectionService.IsWindows();
            var result2 = _platformDetectionService.IsWindows();

            // Assert
            Assert.That(result1, Is.EqualTo(result2), "IsWindows should return consistent results");
        }

        [Test]
        public void IsLinux_ShouldReturnConsistentResult()
        {
            // Act
            var result1 = _platformDetectionService.IsLinux();
            var result2 = _platformDetectionService.IsLinux();

            // Assert
            Assert.That(result1, Is.EqualTo(result2), "IsLinux should return consistent results");
        }

        [Test]
        public void PlatformDetection_ShouldBeConsistentBetweenMethods()
        {
            // Act
            var currentPlatform = _platformDetectionService.GetCurrentPlatform();
            var isWindows = _platformDetectionService.IsWindows();
            var isLinux = _platformDetectionService.IsLinux();

            // Assert
            if (currentPlatform == OSPlatform.Windows)
            {
                Assert.That(isWindows, Is.True, "IsWindows should return true when current platform is Windows");
                Assert.That(isLinux, Is.False, "IsLinux should return false when current platform is Windows");
            }
            else if (currentPlatform == OSPlatform.Linux)
            {
                Assert.That(isLinux, Is.True, "IsLinux should return true when current platform is Linux");
                Assert.That(isWindows, Is.False, "IsWindows should return false when current platform is Linux");
            }
        }

        [Test]
        public void GetCurrentPlatform_ShouldReturnSameValueOnMultipleCalls()
        {
            // Act
            var result1 = _platformDetectionService.GetCurrentPlatform();
            var result2 = _platformDetectionService.GetCurrentPlatform();

            // Assert
            Assert.That(result1, Is.EqualTo(result2), "GetCurrentPlatform should return the same value on multiple calls");
        }

        [Test]
        public void PlatformDetection_ShouldMatchRuntimeInformation()
        {
            // Act
            var isWindows = _platformDetectionService.IsWindows();
            var isLinux = _platformDetectionService.IsLinux();

            // Assert
            Assert.That(isWindows, Is.EqualTo(RuntimeInformation.IsOSPlatform(OSPlatform.Windows)), 
                "IsWindows should match RuntimeInformation.IsOSPlatform(OSPlatform.Windows)");
            Assert.That(isLinux, Is.EqualTo(RuntimeInformation.IsOSPlatform(OSPlatform.Linux)), 
                "IsLinux should match RuntimeInformation.IsOSPlatform(OSPlatform.Linux)");
        }

        [Test]
        public void Constructor_ShouldInitializePlatformCorrectly()
        {
            // Act
            var service = new PlatformDetectionService();
            var platform = service.GetCurrentPlatform();

            // Assert
            Assert.That(platform, Is.Not.Null);
            
            // Verify that the cached platform matches the current runtime detection
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                Assert.That(platform, Is.EqualTo(OSPlatform.Windows));
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                Assert.That(platform, Is.EqualTo(OSPlatform.Linux));
            }
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            {
                Assert.That(platform, Is.EqualTo(OSPlatform.OSX));
            }
            else
            {
                // Should default to Linux as per requirements 1.4
                Assert.That(platform, Is.EqualTo(OSPlatform.Linux));
            }
        }
    }
}