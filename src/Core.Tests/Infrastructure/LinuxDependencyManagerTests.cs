using BookStore.Domain.Interfaces;
using BookStore.Infrastructure.Services;
using System.Collections.Generic;
using System.Threading.Tasks;
using Xunit;

namespace Core.Tests.Infrastructure
{
    /// <summary>
    /// Unit tests for LinuxDependencyManager
    /// </summary>
    public class LinuxDependencyManagerTests
    {
        private readonly LinuxDependencyManager _dependencyManager;

        public LinuxDependencyManagerTests()
        {
            _dependencyManager = new LinuxDependencyManager();
        }

        [Fact]
        public async Task CheckDependenciesAsync_ShouldReturnBool()
        {
            // Act
            var result = await _dependencyManager.CheckDependenciesAsync();

            // Assert
            Assert.IsType<bool>(result);
        }

        [Fact]
        public async Task EnsureDependenciesAsync_OnNonLinux_ShouldReturnFalse()
        {
            // Act - On Windows (test environment), this should return false
            var result = await _dependencyManager.EnsureDependenciesAsync();
            
            // Assert - Should return false on non-Linux systems
            Assert.False(result);
        }

        [Fact]
        public async Task DetectPackageManagerAsync_ShouldReturnPackageManagerOrNull()
        {
            // Act
            var result = await _dependencyManager.DetectPackageManagerAsync();

            // Assert
            Assert.True(result == null || System.Enum.IsDefined(typeof(PackageManager), result.Value));
        }

        [Theory]
        [InlineData(PackageManager.Apt)]
        [InlineData(PackageManager.Yum)]
        [InlineData(PackageManager.Dnf)]
        [InlineData(PackageManager.Pacman)]
        [InlineData(PackageManager.Zypper)]
        [InlineData(PackageManager.Apk)]
        public void GetInstallationInstructions_WithPackageManager_ShouldReturnInstructions(PackageManager packageManager)
        {
            // Act
            var instructions = _dependencyManager.GetInstallationInstructions(packageManager);

            // Assert
            Assert.NotNull(instructions);
            Assert.NotEmpty(instructions);
            Assert.Contains("install", instructions.ToLower());
        }

        [Fact]
        public void GetInstallationInstructions_WithNullPackageManager_ShouldReturnGenericInstructions()
        {
            // Act
            var instructions = _dependencyManager.GetInstallationInstructions(null);

            // Assert
            Assert.NotNull(instructions);
            Assert.NotEmpty(instructions);
            Assert.Contains("Generic installation instructions", instructions);
        }

        [Fact]
        public void GetInstallationInstructions_WithApt_ShouldContainAptCommands()
        {
            // Act
            var instructions = _dependencyManager.GetInstallationInstructions(PackageManager.Apt);

            // Assert
            Assert.Contains("apt-get", instructions);
            Assert.Contains("sudo", instructions);
            Assert.Contains("ffmpeg", instructions);
            Assert.Contains("yt-dlp", instructions);
        }

        [Fact]
        public void GetInstallationInstructions_WithYum_ShouldContainYumCommands()
        {
            // Act
            var instructions = _dependencyManager.GetInstallationInstructions(PackageManager.Yum);

            // Assert
            Assert.Contains("yum", instructions);
            Assert.Contains("epel-release", instructions);
            Assert.Contains("ffmpeg", instructions);
            Assert.Contains("yt-dlp", instructions);
        }

        [Fact]
        public void GetInstallationInstructions_WithDnf_ShouldContainDnfCommands()
        {
            // Act
            var instructions = _dependencyManager.GetInstallationInstructions(PackageManager.Dnf);

            // Assert
            Assert.Contains("dnf", instructions);
            Assert.Contains("ffmpeg", instructions);
            Assert.Contains("yt-dlp", instructions);
        }

        [Fact]
        public void GetInstallationInstructions_WithPacman_ShouldContainPacmanCommands()
        {
            // Act
            var instructions = _dependencyManager.GetInstallationInstructions(PackageManager.Pacman);

            // Assert
            Assert.Contains("pacman", instructions);
            Assert.Contains("ffmpeg", instructions);
            Assert.Contains("yt-dlp", instructions);
        }

        [Fact]
        public void GetInstallationInstructions_WithZypper_ShouldContainZypperCommands()
        {
            // Act
            var instructions = _dependencyManager.GetInstallationInstructions(PackageManager.Zypper);

            // Assert
            Assert.Contains("zypper", instructions);
            Assert.Contains("ffmpeg", instructions);
            Assert.Contains("yt-dlp", instructions);
        }

        [Fact]
        public void GetInstallationInstructions_WithApk_ShouldContainApkCommands()
        {
            // Act
            var instructions = _dependencyManager.GetInstallationInstructions(PackageManager.Apk);

            // Assert
            Assert.Contains("apk", instructions);
            Assert.Contains("ffmpeg", instructions);
            Assert.Contains("yt-dlp", instructions);
        }

        [Fact]
        public void GetInstallationInstructions_ShouldIncludeAlternativeInstallationMethods()
        {
            // Act
            var instructions = _dependencyManager.GetInstallationInstructions(PackageManager.Apt);

            // Assert
            Assert.Contains("Alternative", instructions);
            Assert.Contains("github.com/yt-dlp/yt-dlp", instructions);
            Assert.Contains("wget", instructions);
        }

        [Fact]
        public void GetInstallationInstructions_ShouldIncludePathInformation()
        {
            // Act
            var instructions = _dependencyManager.GetInstallationInstructions(PackageManager.Apt);

            // Assert
            Assert.Contains(".local/bin", instructions);
            Assert.Contains("PATH", instructions);
        }

        [Fact]
        public async Task IsYtDlpAvailableAsync_ShouldReturnBool()
        {
            // Act
            var result = await _dependencyManager.IsYtDlpAvailableAsync();

            // Assert
            Assert.IsType<bool>(result);
        }

        [Fact]
        public async Task IsFfmpegAvailableAsync_ShouldReturnBool()
        {
            // Act
            var result = await _dependencyManager.IsFfmpegAvailableAsync();

            // Assert
            Assert.IsType<bool>(result);
        }

        [Fact]
        public async Task GetDependencyStatusAsync_ShouldReturnDictionary()
        {
            // Act
            var status = await _dependencyManager.GetDependencyStatusAsync();

            // Assert
            Assert.NotNull(status);
            Assert.IsType<Dictionary<string, bool>>(status);
            Assert.Contains("yt-dlp", status.Keys);
            Assert.Contains("ffmpeg", status.Keys);
            Assert.Contains("python3", status.Keys);
            Assert.Contains("pip3", status.Keys);
        }

        [Fact]
        public async Task InstallMissingDependenciesAsync_ShouldReturnDictionary()
        {
            // Act
            var results = await _dependencyManager.InstallMissingDependenciesAsync();

            // Assert
            Assert.NotNull(results);
            Assert.IsType<Dictionary<string, bool>>(results);
            Assert.Contains("yt-dlp", results.Keys);
            Assert.Contains("ffmpeg", results.Keys);
        }

        [Fact]
        public async Task GetMissingDependenciesErrorAsync_ShouldReturnString()
        {
            // Act
            var error = await _dependencyManager.GetMissingDependenciesErrorAsync();

            // Assert
            Assert.NotNull(error);
            Assert.IsType<string>(error);
            Assert.NotEmpty(error);
        }

        [Fact]
        public async Task CheckDependenciesAsync_OnNonLinux_ShouldReturnFalse()
        {
            // Act - On Windows (test environment), this should return false
            var result = await _dependencyManager.CheckDependenciesAsync();

            // Assert - Should return false on non-Linux systems
            Assert.False(result);
        }

        [Fact]
        public async Task DetectPackageManagerAsync_OnNonLinux_ShouldReturnNull()
        {
            // Act - On Windows (test environment), this should return null
            var result = await _dependencyManager.DetectPackageManagerAsync();

            // Assert - Should return null on non-Linux systems
            Assert.Null(result);
        }
    }
}