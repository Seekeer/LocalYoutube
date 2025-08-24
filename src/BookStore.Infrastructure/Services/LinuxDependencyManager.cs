using BookStore.Domain.Interfaces;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

namespace BookStore.Infrastructure.Services
{
    /// <summary>
    /// Manages Linux-specific dependencies and utilities for download functionality
    /// </summary>
    public class LinuxDependencyManager : ILinuxDependencyManager
    {
        private const string YtDlpExecutable = "yt-dlp";
        private const string FfmpegExecutable = "ffmpeg";
        private const string PythonExecutable = "python3";
        private const string PipExecutable = "pip3";

        /// <summary>
        /// Checks if all required dependencies are available
        /// </summary>
        /// <returns>True if all dependencies are available, false otherwise</returns>
        public async Task<bool> CheckDependenciesAsync()
        {
            // Only check dependencies on Linux systems
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                return false;
            }

            var ytdlpAvailable = await IsCommandAvailableAsync(YtDlpExecutable);
            var ffmpegAvailable = await IsCommandAvailableAsync(FfmpegExecutable);
            
            return ytdlpAvailable && ffmpegAvailable;
        }

        /// <summary>
        /// Ensures all required dependencies are installed and available
        /// </summary>
        /// <returns>True if dependencies are successfully ensured, false otherwise</returns>
        public async Task<bool> EnsureDependenciesAsync()
        {
            try
            {
                // Only attempt installation on Linux systems
                if (!RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
                {
                    // On non-Linux systems, just return false to indicate dependencies aren't available
                    return false;
                }

                // Check and install yt-dlp
                if (!await IsCommandAvailableAsync(YtDlpExecutable))
                {
                    var ytdlpInstalled = await InstallYtDlpAsync();
                    if (!ytdlpInstalled)
                    {
                        var packageManager = await DetectPackageManagerAsync();
                        var instructions = GetInstallationInstructions(packageManager);
                        throw new InvalidOperationException($"Failed to install yt-dlp automatically. Please install it manually.\n\n{instructions}");
                    }
                }

                // Check ffmpeg (warn if not available but don't fail)
                if (!await IsCommandAvailableAsync(FfmpegExecutable))
                {
                    await WarnAboutMissingFfmpegAsync();
                }

                return true;
            }
            catch (Exception ex) when (!(ex is InvalidOperationException))
            {
                var packageManager = await DetectPackageManagerAsync();
                var instructions = GetInstallationInstructions(packageManager);
                throw new InvalidOperationException($"Failed to ensure Linux dependencies: {ex.Message}\n\n{instructions}", ex);
            }
        }

        /// <summary>
        /// Detects the available package manager on the system
        /// </summary>
        /// <returns>The detected package manager or null if none found</returns>
        public async Task<PackageManager?> DetectPackageManagerAsync()
        {
            // Only detect package managers on Linux systems
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                return null;
            }

            var packageManagers = new[]
            {
                new { Manager = PackageManager.Apt, Command = "apt-get" },
                new { Manager = PackageManager.Yum, Command = "yum" },
                new { Manager = PackageManager.Dnf, Command = "dnf" },
                new { Manager = PackageManager.Pacman, Command = "pacman" },
                new { Manager = PackageManager.Zypper, Command = "zypper" },
                new { Manager = PackageManager.Apk, Command = "apk" }
            };

            try
            {
                foreach (var pm in packageManagers)
                {
                    if (await IsCommandAvailableAsync(pm.Command))
                    {
                        return pm.Manager;
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error detecting package manager: {ex.Message}");
            }

            return null;
        }

        /// <summary>
        /// Gets installation instructions for missing dependencies
        /// </summary>
        /// <param name="packageManager">The detected package manager</param>
        /// <returns>Installation instructions string</returns>
        public string GetInstallationInstructions(PackageManager? packageManager)
        {
            var instructions = "To install missing dependencies:\n\n";

            if (packageManager.HasValue)
            {
                instructions += GetPackageManagerInstructions(packageManager.Value);
            }
            else
            {
                instructions += GetGenericInstallationInstructions();
            }

            return instructions;
        }

        /// <summary>
        /// Gets a detailed error message for missing dependencies
        /// </summary>
        /// <returns>A detailed error message with installation instructions</returns>
        public async Task<string> GetMissingDependenciesErrorAsync()
        {
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                return "Linux dependency manager can only be used on Linux systems.";
            }

            var status = await GetDependencyStatusAsync();
            var packageManager = await DetectPackageManagerAsync();
            
            var missingDeps = new List<string>();
            
            if (!status[YtDlpExecutable])
                missingDeps.Add("yt-dlp");
            if (!status[FfmpegExecutable])
                missingDeps.Add("ffmpeg");
            
            if (missingDeps.Count == 0)
            {
                return "All required dependencies are available.";
            }

            var errorMessage = $"Missing required dependencies: {string.Join(", ", missingDeps)}\n\n";
            errorMessage += GetInstallationInstructions(packageManager);
            
            return errorMessage;
        }

        /// <summary>
        /// Checks if yt-dlp is available on the system
        /// </summary>
        /// <returns>True if yt-dlp is available, false otherwise</returns>
        public async Task<bool> IsYtDlpAvailableAsync()
        {
            return await IsCommandAvailableAsync(YtDlpExecutable);
        }

        /// <summary>
        /// Checks if ffmpeg is available on the system
        /// </summary>
        /// <returns>True if ffmpeg is available, false otherwise</returns>
        public async Task<bool> IsFfmpegAvailableAsync()
        {
            return await IsCommandAvailableAsync(FfmpegExecutable);
        }

        /// <summary>
        /// Gets detailed dependency status information
        /// </summary>
        /// <returns>A dictionary containing the status of each dependency</returns>
        public async Task<Dictionary<string, bool>> GetDependencyStatusAsync()
        {
            var status = new Dictionary<string, bool>();
            
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                status[YtDlpExecutable] = await IsCommandAvailableAsync(YtDlpExecutable);
                status[FfmpegExecutable] = await IsCommandAvailableAsync(FfmpegExecutable);
                status[PythonExecutable] = await IsCommandAvailableAsync(PythonExecutable);
                status[PipExecutable] = await IsCommandAvailableAsync(PipExecutable);
            }
            else
            {
                // On non-Linux systems, mark all as unavailable
                status[YtDlpExecutable] = false;
                status[FfmpegExecutable] = false;
                status[PythonExecutable] = false;
                status[PipExecutable] = false;
            }

            return status;
        }

        /// <summary>
        /// Attempts to install missing dependencies with better error handling
        /// </summary>
        /// <returns>A dictionary indicating which dependencies were successfully installed</returns>
        public async Task<Dictionary<string, bool>> InstallMissingDependenciesAsync()
        {
            var results = new Dictionary<string, bool>();

            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            {
                results[YtDlpExecutable] = false;
                results[FfmpegExecutable] = false;
                return results;
            }

            try
            {
                // Try to install yt-dlp if missing
                if (!await IsCommandAvailableAsync(YtDlpExecutable))
                {
                    results[YtDlpExecutable] = await InstallYtDlpAsync();
                }
                else
                {
                    results[YtDlpExecutable] = true;
                }

                // ffmpeg is typically installed via package manager, so we don't auto-install it
                results[FfmpegExecutable] = await IsCommandAvailableAsync(FfmpegExecutable);

                return results;
            }
            catch (Exception)
            {
                results[YtDlpExecutable] = false;
                results[FfmpegExecutable] = false;
                return results;
            }
        }

        private async Task<bool> IsCommandAvailableAsync(string command)
        {
            try
            {
                var processStartInfo = new ProcessStartInfo
                {
                    FileName = "/bin/bash",
                    Arguments = $"-c \"command -v {command}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };

                using var process = new Process { StartInfo = processStartInfo };
                process.Start();
                await process.WaitForExitAsync();

                return process.ExitCode == 0;
            }
            catch
            {
                return false;
            }
        }

        private async Task<bool> InstallYtDlpAsync()
        {
            try
            {
                // Try pip3 installation first
                if (await IsCommandAvailableAsync(PipExecutable))
                {
                    var result = await InstallViaPipAsync(YtDlpExecutable);
                    if (result)
                    {
                        // Verify installation was successful
                        return await IsCommandAvailableAsync(YtDlpExecutable);
                    }
                }

                // Try pip installation
                if (await IsCommandAvailableAsync("pip"))
                {
                    var result = await InstallViaPipAsync(YtDlpExecutable, "pip");
                    if (result)
                    {
                        return await IsCommandAvailableAsync(YtDlpExecutable);
                    }
                }

                // Try python3 -m pip
                if (await IsCommandAvailableAsync(PythonExecutable))
                {
                    var result = await InstallViaPythonPipAsync(YtDlpExecutable);
                    if (result)
                    {
                        return await IsCommandAvailableAsync(YtDlpExecutable);
                    }
                }

                return false;
            }
            catch (Exception ex)
            {
                // Log the exception for debugging purposes
                Console.WriteLine($"Error installing yt-dlp: {ex.Message}");
                return false;
            }
        }

        private async Task<bool> InstallViaPipAsync(string package, string pipCommand = "pip3")
        {
            try
            {
                var processStartInfo = new ProcessStartInfo
                {
                    FileName = "/bin/bash",
                    Arguments = $"-c \"{pipCommand} install --user {package}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };

                using var process = new Process { StartInfo = processStartInfo };
                process.Start();
                await process.WaitForExitAsync();

                if (process.ExitCode == 0)
                {
                    // Update PATH to include user local bin
                    var userLocalBin = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".local", "bin");
                    var currentPath = Environment.GetEnvironmentVariable("PATH");
                    if (!currentPath.Contains(userLocalBin))
                    {
                        Environment.SetEnvironmentVariable("PATH", $"{userLocalBin}:{currentPath}");
                    }
                    return true;
                }

                return false;
            }
            catch
            {
                return false;
            }
        }

        private async Task<bool> InstallViaPythonPipAsync(string package)
        {
            try
            {
                var processStartInfo = new ProcessStartInfo
                {
                    FileName = "/bin/bash",
                    Arguments = $"-c \"{PythonExecutable} -m pip install --user {package}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };

                using var process = new Process { StartInfo = processStartInfo };
                process.Start();
                await process.WaitForExitAsync();

                if (process.ExitCode == 0)
                {
                    // Update PATH to include user local bin
                    var userLocalBin = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".local", "bin");
                    var currentPath = Environment.GetEnvironmentVariable("PATH");
                    if (!currentPath.Contains(userLocalBin))
                    {
                        Environment.SetEnvironmentVariable("PATH", $"{userLocalBin}:{currentPath}");
                    }
                    return true;
                }

                return false;
            }
            catch
            {
                return false;
            }
        }

        private async Task WarnAboutMissingFfmpegAsync()
        {
            var packageManager = await DetectPackageManagerAsync();
            var instructions = GetFfmpegInstallationInstructions(packageManager);
            
            Console.WriteLine("Warning: ffmpeg not found. Some video processing features may not work.");
            Console.WriteLine(instructions);
        }

        private string GetPackageManagerInstructions(PackageManager packageManager)
        {
            return packageManager switch
            {
                PackageManager.Apt => GetAptInstructions(),
                PackageManager.Yum => GetYumInstructions(),
                PackageManager.Dnf => GetDnfInstructions(),
                PackageManager.Pacman => GetPacmanInstructions(),
                PackageManager.Zypper => GetZypperInstructions(),
                PackageManager.Apk => GetApkInstructions(),
                _ => GetGenericInstallationInstructions()
            };
        }

        private string GetAptInstructions()
        {
            return @"For Ubuntu/Debian systems:
1. Update package list: sudo apt-get update
2. Install ffmpeg: sudo apt-get install ffmpeg
3. Install Python and pip: sudo apt-get install python3 python3-pip
4. Install yt-dlp: pip3 install --user yt-dlp

Alternative for yt-dlp:
- Download binary: wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O ~/.local/bin/yt-dlp && chmod +x ~/.local/bin/yt-dlp

Note: Make sure ~/.local/bin is in your PATH environment variable.
Add this line to your ~/.bashrc or ~/.profile: export PATH=""$HOME/.local/bin:$PATH""";
        }

        private string GetYumInstructions()
        {
            return @"For RHEL/CentOS systems:
1. Install EPEL repository: sudo yum install epel-release
2. Install ffmpeg: sudo yum install ffmpeg
3. Install Python and pip: sudo yum install python3 python3-pip
4. Install yt-dlp: pip3 install --user yt-dlp

Alternative for yt-dlp:
- Download binary: wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O ~/.local/bin/yt-dlp && chmod +x ~/.local/bin/yt-dlp

Note: Make sure ~/.local/bin is in your PATH environment variable.
Add this line to your ~/.bashrc or ~/.profile: export PATH=""$HOME/.local/bin:$PATH""";
        }

        private string GetDnfInstructions()
        {
            return @"For Fedora systems:
1. Install ffmpeg: sudo dnf install ffmpeg
2. Install Python and pip: sudo dnf install python3 python3-pip
3. Install yt-dlp: pip3 install --user yt-dlp

Alternative for yt-dlp:
- Download binary: wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O ~/.local/bin/yt-dlp && chmod +x ~/.local/bin/yt-dlp

Note: Make sure ~/.local/bin is in your PATH environment variable.
Add this line to your ~/.bashrc or ~/.profile: export PATH=""$HOME/.local/bin:$PATH""";
        }

        private string GetPacmanInstructions()
        {
            return @"For Arch Linux systems:
1. Install ffmpeg: sudo pacman -S ffmpeg
2. Install Python and pip: sudo pacman -S python python-pip
3. Install yt-dlp: pip install --user yt-dlp

Alternative for yt-dlp:
- Install from AUR: yay -S yt-dlp
- Download binary: wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O ~/.local/bin/yt-dlp && chmod +x ~/.local/bin/yt-dlp

Note: Make sure ~/.local/bin is in your PATH environment variable.
Add this line to your ~/.bashrc or ~/.profile: export PATH=""$HOME/.local/bin:$PATH""";
        }

        private string GetZypperInstructions()
        {
            return @"For openSUSE systems:
1. Install ffmpeg: sudo zypper install ffmpeg
2. Install Python and pip: sudo zypper install python3 python3-pip
3. Install yt-dlp: pip3 install --user yt-dlp

Alternative for yt-dlp:
- Download binary: wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O ~/.local/bin/yt-dlp && chmod +x ~/.local/bin/yt-dlp

Note: Make sure ~/.local/bin is in your PATH environment variable.
Add this line to your ~/.bashrc or ~/.profile: export PATH=""$HOME/.local/bin:$PATH""";
        }

        private string GetApkInstructions()
        {
            return @"For Alpine Linux systems:
1. Install ffmpeg: sudo apk add ffmpeg
2. Install Python and pip: sudo apk add python3 py3-pip
3. Install yt-dlp: pip3 install --user yt-dlp

Alternative for yt-dlp:
- Download binary: wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O ~/.local/bin/yt-dlp && chmod +x ~/.local/bin/yt-dlp

Note: Make sure ~/.local/bin is in your PATH environment variable.
Add this line to your ~/.bashrc or ~/.profile: export PATH=""$HOME/.local/bin:$PATH""";
        }

        private string GetGenericInstallationInstructions()
        {
            return @"Generic installation instructions:
1. Install ffmpeg from your distribution's package manager or from https://ffmpeg.org/download.html
2. Install Python 3 and pip from your distribution's package manager
3. Install yt-dlp using pip: pip3 install --user yt-dlp
4. Alternatively, download yt-dlp binary from: https://github.com/yt-dlp/yt-dlp/releases

Note: Make sure ~/.local/bin is in your PATH environment variable.
Add this line to your ~/.bashrc or ~/.profile: export PATH=""$HOME/.local/bin:$PATH""";
        }

        private string GetFfmpegInstallationInstructions(PackageManager? packageManager)
        {
            if (!packageManager.HasValue)
            {
                return "Please install ffmpeg using your system's package manager or download from https://ffmpeg.org/download.html";
            }

            return packageManager.Value switch
            {
                PackageManager.Apt => "Install with: sudo apt-get update && sudo apt-get install ffmpeg",
                PackageManager.Yum => "Install with: sudo yum install epel-release && sudo yum install ffmpeg",
                PackageManager.Dnf => "Install with: sudo dnf install ffmpeg",
                PackageManager.Pacman => "Install with: sudo pacman -S ffmpeg",
                PackageManager.Zypper => "Install with: sudo zypper install ffmpeg",
                PackageManager.Apk => "Install with: sudo apk add ffmpeg",
                _ => "Please install ffmpeg using your system's package manager"
            };
        }
    }


}