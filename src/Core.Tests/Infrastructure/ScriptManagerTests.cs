using BookStore.Domain.Interfaces;
using BookStore.Infrastructure.Services;
using System;
using System.IO;
using System.Runtime.InteropServices;
using Xunit;

namespace Core.Tests.Infrastructure
{
    /// <summary>
    /// Unit tests for ScriptManager functionality
    /// </summary>
    public class ScriptManagerTests
    {
        private readonly IScriptManager _scriptManager;

        public ScriptManagerTests()
        {
            _scriptManager = new ScriptManager();
        }

        [Fact]
        public void GetUtilitiesScript_Windows_ReturnsValidPowerShellScript()
        {
            // Act
            var script = _scriptManager.GetUtilitiesScript(OSPlatform.Windows);

            // Assert
            Assert.NotNull(script);
            Assert.NotEmpty(script);
            Assert.Contains("$ytdlp", script);
            Assert.Contains("$ffmpeg", script);
            Assert.Contains("Start-BitsTransfer", script);
        }

        [Fact]
        public void GetUtilitiesScript_Linux_ReturnsValidBashScript()
        {
            // Act
            var script = _scriptManager.GetUtilitiesScript(OSPlatform.Linux);

            // Assert
            Assert.NotNull(script);
            Assert.NotEmpty(script);
            Assert.Contains("#!/bin/bash", script);
            Assert.Contains("command_exists", script);
            Assert.Contains("install_ytdlp", script);
        }

        [Fact]
        public void GetUtilitiesScript_UnsupportedPlatform_ThrowsPlatformNotSupportedException()
        {
            // Act & Assert
            Assert.Throws<PlatformNotSupportedException>(() => 
                _scriptManager.GetUtilitiesScript(OSPlatform.OSX));
        }

        [Fact]
        public void GetDownloadScript_Windows_WithoutProxy_ReturnsValidScript()
        {
            // Arrange
            var url = "https://example.com/video";
            var fileName = "test_video";

            // Act
            var script = _scriptManager.GetDownloadScript(OSPlatform.Windows, url, fileName);

            // Assert
            Assert.NotNull(script);
            Assert.NotEmpty(script);
            Assert.Contains(url, script);
            Assert.Contains(fileName, script);
            Assert.Contains("$ytdlp = 'yt-dlp.exe'", script);
            Assert.Contains("Start-Process", script);
            Assert.DoesNotContain("--proxy", script);
        }

        [Fact]
        public void GetDownloadScript_Windows_WithProxy_ReturnsScriptWithProxy()
        {
            // Arrange
            var url = "https://example.com/video";
            var fileName = "test_video";
            var proxySettings = "http://proxy.example.com:8080";

            // Act
            var script = _scriptManager.GetDownloadScript(OSPlatform.Windows, url, fileName, proxySettings);

            // Assert
            Assert.NotNull(script);
            Assert.NotEmpty(script);
            Assert.Contains(url, script);
            Assert.Contains(fileName, script);
            Assert.Contains($"--proxy {proxySettings}", script);
        }

        [Fact]
        public void GetDownloadScript_Linux_WithoutProxy_ReturnsValidScript()
        {
            // Arrange
            var url = "https://example.com/video";
            var fileName = "test_video";

            // Act
            var script = _scriptManager.GetDownloadScript(OSPlatform.Linux, url, fileName);

            // Assert
            Assert.NotNull(script);
            Assert.NotEmpty(script);
            Assert.Contains(url, script);
            Assert.Contains(fileName, script);
            Assert.Contains("#!/bin/bash", script);
            Assert.Contains("YTDLP=\"yt-dlp\"", script);
            Assert.DoesNotContain("--proxy", script);
        }

        [Fact]
        public void GetDownloadScript_Linux_WithProxy_ReturnsScriptWithProxy()
        {
            // Arrange
            var url = "https://example.com/video";
            var fileName = "test_video";
            var proxySettings = "http://proxy.example.com:8080";

            // Act
            var script = _scriptManager.GetDownloadScript(OSPlatform.Linux, url, fileName, proxySettings);

            // Assert
            Assert.NotNull(script);
            Assert.NotEmpty(script);
            Assert.Contains(url, script);
            Assert.Contains(fileName, script);
            Assert.Contains($"--proxy {proxySettings}", script);
        }

        [Fact]
        public void GetDownloadScript_UnsupportedPlatform_ThrowsPlatformNotSupportedException()
        {
            // Arrange
            var url = "https://example.com/video";
            var fileName = "test_video";

            // Act & Assert
            Assert.Throws<PlatformNotSupportedException>(() => 
                _scriptManager.GetDownloadScript(OSPlatform.OSX, url, fileName));
        }

        [Theory]
        [InlineData("")]
        [InlineData(null)]
        [InlineData("   ")]
        public void ValidateScript_EmptyOrNullScript_ReturnsFalse(string scriptContent)
        {
            // Act
            var isValid = _scriptManager.ValidateScript(OSPlatform.Windows, scriptContent);

            // Assert
            Assert.False(isValid);
        }

        [Fact]
        public void ValidateScript_Windows_ValidPowerShellScript_ReturnsTrue()
        {
            // Arrange
            var scriptContent = "$ytdlp = 'yt-dlp.exe'\nStart-Process -FilePath $ytdlp";

            // Act
            var isValid = _scriptManager.ValidateScript(OSPlatform.Windows, scriptContent);

            // Assert
            Assert.True(isValid);
        }

        [Fact]
        public void ValidateScript_Linux_ValidBashScript_ReturnsTrue()
        {
            // Arrange
            var scriptContent = "#!/bin/bash\ncommand -v yt-dlp";

            // Act
            var isValid = _scriptManager.ValidateScript(OSPlatform.Linux, scriptContent);

            // Assert
            Assert.True(isValid);
        }

        [Fact]
        public void ValidateScript_Windows_InvalidScript_ReturnsFalse()
        {
            // Arrange
            var scriptContent = "#!/bin/bash\necho 'This is bash on Windows'";

            // Act
            var isValid = _scriptManager.ValidateScript(OSPlatform.Windows, scriptContent);

            // Assert
            Assert.False(isValid);
        }

        [Fact]
        public void ValidateScript_Linux_InvalidScript_ReturnsFalse()
        {
            // Arrange
            var scriptContent = "$variable = 'PowerShell on Linux'";

            // Act
            var isValid = _scriptManager.ValidateScript(OSPlatform.Linux, scriptContent);

            // Assert
            Assert.False(isValid);
        }

        [Fact]
        public void GetDownloadScript_ParameterSubstitution_CorrectlySubstitutesAllParameters()
        {
            // Arrange
            var url = "https://youtube.com/watch?v=test123";
            var fileName = "my_test_video";
            var proxySettings = "socks5://127.0.0.1:1080";

            // Act
            var windowsScript = _scriptManager.GetDownloadScript(OSPlatform.Windows, url, fileName, proxySettings);
            var linuxScript = _scriptManager.GetDownloadScript(OSPlatform.Linux, url, fileName, proxySettings);

            // Assert - Windows
            Assert.Contains(url, windowsScript);
            Assert.Contains(fileName, windowsScript);
            Assert.Contains(proxySettings, windowsScript);

            // Assert - Linux
            Assert.Contains(url, linuxScript);
            Assert.Contains(fileName, linuxScript);
            Assert.Contains(proxySettings, linuxScript);
        }

        [Fact]
        public void GetDownloadScript_SpecialCharactersInParameters_HandlesCorrectly()
        {
            // Arrange
            var url = "https://example.com/video?param=value&other=test";
            var fileName = "test-video_with-special.chars";
            var proxySettings = "http://user:pass@proxy.com:8080";

            // Act
            var windowsScript = _scriptManager.GetDownloadScript(OSPlatform.Windows, url, fileName, proxySettings);
            var linuxScript = _scriptManager.GetDownloadScript(OSPlatform.Linux, url, fileName, proxySettings);

            // Assert
            Assert.Contains(url, windowsScript);
            Assert.Contains(fileName, windowsScript);
            Assert.Contains(proxySettings, windowsScript);

            Assert.Contains(url, linuxScript);
            Assert.Contains(fileName, linuxScript);
            Assert.Contains(proxySettings, linuxScript);
        }

        [Fact]
        public void GetDownloadScript_EmptyProxySettings_DoesNotIncludeProxyFlag()
        {
            // Arrange
            var url = "https://example.com/video";
            var fileName = "test_video";

            // Act
            var windowsScript = _scriptManager.GetDownloadScript(OSPlatform.Windows, url, fileName, "");
            var linuxScript = _scriptManager.GetDownloadScript(OSPlatform.Linux, url, fileName, "");

            // Assert
            Assert.DoesNotContain("--proxy", windowsScript);
            Assert.DoesNotContain("--proxy", linuxScript);
        }

        [Fact]
        public void GetDownloadScript_BothPlatforms_ContainRequiredDownloadParameters()
        {
            // Arrange
            var url = "https://example.com/video";
            var fileName = "test_video";

            // Act
            var windowsScript = _scriptManager.GetDownloadScript(OSPlatform.Windows, url, fileName);
            var linuxScript = _scriptManager.GetDownloadScript(OSPlatform.Linux, url, fileName);

            // Assert - Both should contain essential yt-dlp parameters
            Assert.Contains("--fragment-retries 30", windowsScript);
            Assert.Contains("--write-info-json", windowsScript);
            Assert.Contains("--merge-output-format mp4", windowsScript);

            Assert.Contains("--fragment-retries 30", linuxScript);
            Assert.Contains("--write-info-json", linuxScript);
            Assert.Contains("--merge-output-format mp4", linuxScript);
        }
    }
}