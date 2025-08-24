using BookStore.Domain.Interfaces;
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace BookStore.Infrastructure.Services
{
    /// <summary>
    /// Manages platform-specific download scripts and handles parameter substitution
    /// </summary>
    public class ScriptManager : IScriptManager
    {
        private const string WindowsUtilitiesScriptPath = @"Assets\downloadScript.txt";
        private const string LinuxUtilitiesScriptPath = @"Assets/downloadScript.sh";

        /// <summary>
        /// Gets the utilities installation script for the specified platform
        /// </summary>
        /// <param name="platform">The target operating system platform</param>
        /// <returns>The utilities script content</returns>
        public string GetUtilitiesScript(OSPlatform platform)
        {
            if (platform == OSPlatform.Windows)
            {
                return GetWindowsUtilitiesScript();
            }
            else if (platform == OSPlatform.Linux)
            {
                return GetLinuxUtilitiesScript();
            }
            else
            {
                throw new PlatformNotSupportedException($"Platform {platform} is not supported");
            }
        }

        /// <summary>
        /// Gets the download script template for the specified platform with parameter substitution
        /// </summary>
        /// <param name="platform">The target operating system platform</param>
        /// <param name="url">The URL to download from</param>
        /// <param name="fileName">The target file name without extension</param>
        /// <param name="proxySettings">Optional proxy configuration string</param>
        /// <returns>The complete download script with parameters substituted</returns>
        public string GetDownloadScript(OSPlatform platform, string url, string fileName, string proxySettings = "")
        {
            if (platform == OSPlatform.Windows)
            {
                return GetWindowsDownloadScript(url, fileName, proxySettings);
            }
            else if (platform == OSPlatform.Linux)
            {
                return GetLinuxDownloadScript(url, fileName, proxySettings);
            }
            else
            {
                throw new PlatformNotSupportedException($"Platform {platform} is not supported");
            }
        }

        /// <summary>
        /// Validates that the script content is properly formatted for the target platform
        /// </summary>
        /// <param name="platform">The target operating system platform</param>
        /// <param name="scriptContent">The script content to validate</param>
        /// <returns>True if the script is valid for the platform</returns>
        public bool ValidateScript(OSPlatform platform, string scriptContent)
        {
            if (string.IsNullOrWhiteSpace(scriptContent))
                return false;

            if (platform == OSPlatform.Windows)
            {
                // Basic PowerShell validation - check for PowerShell syntax elements
                return scriptContent.Contains("$") || scriptContent.Contains("Start-Process") || scriptContent.Contains("powershell");
            }
            else if (platform == OSPlatform.Linux)
            {
                // Basic bash validation - check for bash syntax elements
                return scriptContent.Contains("#!/bin/bash") || scriptContent.Contains("command -v") || scriptContent.Contains("bash");
            }

            return false;
        }

        private string GetWindowsUtilitiesScript()
        {
            try
            {
                if (File.Exists(WindowsUtilitiesScriptPath))
                {
                    return File.ReadAllText(WindowsUtilitiesScriptPath);
                }
            }
            catch (Exception ex)
            {
                throw new FileNotFoundException($"Could not read Windows utilities script: {ex.Message}", WindowsUtilitiesScriptPath);
            }

            // Fallback to embedded template if file not found
            return GetWindowsUtilitiesTemplate();
        }

        private string GetLinuxUtilitiesScript()
        {
            try
            {
                if (File.Exists(LinuxUtilitiesScriptPath))
                {
                    return File.ReadAllText(LinuxUtilitiesScriptPath);
                }
            }
            catch (Exception ex)
            {
                throw new FileNotFoundException($"Could not read Linux utilities script: {ex.Message}", LinuxUtilitiesScriptPath);
            }

            // Fallback to embedded template if file not found
            return GetLinuxUtilitiesTemplate();
        }

        private string GetWindowsDownloadScript(string url, string fileName, string proxySettings)
        {
            var utilitiesScript = GetWindowsUtilitiesScript();
            var downloadScript = GetWindowsDownloadTemplate(url, fileName, proxySettings);
            
            return utilitiesScript + Environment.NewLine + downloadScript;
        }

        private string GetLinuxDownloadScript(string url, string fileName, string proxySettings)
        {
            var utilitiesScript = GetLinuxUtilitiesScript();
            var downloadScript = GetLinuxDownloadTemplate(url, fileName, proxySettings);
            
            return utilitiesScript + Environment.NewLine + downloadScript;
        }

        private string GetWindowsDownloadTemplate(string url, string fileName, string proxySettings)
        {
            var proxyStr = string.IsNullOrEmpty(proxySettings) ? "" : $"--proxy {proxySettings}";
            
            return $@"
$ytdlp = 'yt-dlp.exe'
$cmd = '-f ""bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"" {proxyStr} --fragment-retries 30 --write-info-json --merge-output-format mp4 {url} -o """"{fileName}""""' 
Start-Process -FilePath $ytdlp -ArgumentList $cmd -Wait -WindowStyle Minimized
";
        }

        private string GetLinuxDownloadTemplate(string url, string fileName, string proxySettings)
        {
            var proxyStr = string.IsNullOrEmpty(proxySettings) ? "" : $"--proxy {proxySettings}";
            
            return $@"
# Download video using yt-dlp
YTDLP=""yt-dlp""
CMD=""-f 'bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best' {proxyStr} --fragment-retries 30 --write-info-json --merge-output-format mp4 '{url}' -o '{fileName}'""

echo ""Starting download with command: $YTDLP $CMD""
$YTDLP $CMD

if [ $? -eq 0 ]; then
    echo ""Download completed successfully""
else
    echo ""Download failed with exit code $?""
    exit 1
fi
";
        }

        private string GetWindowsUtilitiesTemplate()
        {
            return @"$ytdlp = 'yt-dlp.exe'
$ffmpeg = 'ffmpeg.exe'
$filename = 'linklist.txt'
$assets = '.'
$linkYTDLP = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
$linkFFMPEG = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' 

$testytdlp = Test-Path $ytdlp -PathType Leaf
$testffmpeg = Test-Path $ffmpeg -PathType Leaf
if (!$testytdlp) { Start-BitsTransfer -Source $linkYTDLP -Destination $assets }
if (!$testffmpeg) 
{ 
  $zipfile = '.\ffmpeg.zip'
  $temp = '.\temp'
  Start-BitsTransfer -Source $linkFFMPEG -Destination $zipfile
  Expand-Archive $assets\ffmpeg.zip -DestinationPath $temp
  Get-ChildItem -Include $ffmpeg -Path $temp -Recurse -ErrorAction SilentlyContinue | Move-Item -Destination $assets
  Remove-Item -Path $temp -Recurse -ErrorAction SilentlyContinue
  Remove-Item -Path $zipfile -Recurse -ErrorAction SilentlyContinue
}";
        }

        private string GetLinuxUtilitiesTemplate()
        {
            return @"#!/bin/bash

# Linux download utilities script - equivalent to downloadScript.txt for Windows
YTDLP=""yt-dlp""
FFMPEG=""ffmpeg""
ASSETS="".""

# Function to check if a command exists
command_exists() {
    command -v ""$1"" >/dev/null 2>&1
}

# Function to install yt-dlp
install_ytdlp() {
    echo ""Installing yt-dlp...""
    
    # Try pip3 first
    if command_exists pip3; then
        pip3 install --user yt-dlp
        # Add user local bin to PATH if not already there
        export PATH=""$HOME/.local/bin:$PATH""
    elif command_exists pip; then
        pip install --user yt-dlp
        export PATH=""$HOME/.local/bin:$PATH""
    elif command_exists python3; then
        python3 -m pip install --user yt-dlp
        export PATH=""$HOME/.local/bin:$PATH""
    else
        echo ""Error: Python/pip not found. Please install Python and pip to use yt-dlp.""
        echo ""Alternatively, download yt-dlp binary manually from: https://github.com/yt-dlp/yt-dlp/releases""
        exit 1
    fi
}

# Function to install ffmpeg
install_ffmpeg() {
    echo ""Installing ffmpeg...""
    
    # Try different package managers
    if command_exists apt-get; then
        echo ""Please run: sudo apt-get update && sudo apt-get install ffmpeg""
        echo ""Or install ffmpeg manually and ensure it's in your PATH""
    elif command_exists yum; then
        echo ""Please run: sudo yum install ffmpeg""
        echo ""Or install ffmpeg manually and ensure it's in your PATH""
    elif command_exists dnf; then
        echo ""Please run: sudo dnf install ffmpeg""
        echo ""Or install ffmpeg manually and ensure it's in your PATH""
    elif command_exists pacman; then
        echo ""Please run: sudo pacman -S ffmpeg""
        echo ""Or install ffmpeg manually and ensure it's in your PATH""
    else
        echo ""Please install ffmpeg using your system's package manager""
        echo ""Or download from: https://ffmpeg.org/download.html""
    fi
}

# Check and install yt-dlp
if ! command_exists $YTDLP; then
    install_ytdlp
    
    # Check again after installation
    if ! command_exists $YTDLP; then
        echo ""Error: yt-dlp installation failed or not in PATH""
        exit 1
    fi
fi

# Check and install ffmpeg
if ! command_exists $FFMPEG; then
    echo ""Warning: ffmpeg not found. Some video processing features may not work.""
    install_ffmpeg
fi

echo ""Utilities check complete.""";
        }
    }
}