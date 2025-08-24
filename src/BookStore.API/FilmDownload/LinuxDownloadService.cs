using BookStore.Domain.Interfaces;
using BookStore.Domain.Exceptions;
using FileStore.Domain;
using Infrastructure;
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

namespace API.FilmDownload
{
    /// <summary>
    /// Linux-specific implementation of download service using bash scripts
    /// </summary>
    public class LinuxDownloadService : DownloadServiceBase
    {
        private readonly IScriptManager _scriptManager;
        private readonly ILinuxDependencyManager _dependencyManager;
        private readonly IDownloadLogger _downloadLogger;
        private readonly IErrorRecoveryService _errorRecoveryService;

        public LinuxDownloadService(AppConfig config, IScriptManager scriptManager, 
            ILinuxDependencyManager dependencyManager, IDownloadLogger downloadLogger, 
            IErrorRecoveryService errorRecoveryService) : base(config)
        {
            _scriptManager = scriptManager;
            _dependencyManager = dependencyManager;
            _downloadLogger = downloadLogger;
            _errorRecoveryService = errorRecoveryService;
        }

        /// <summary>
        /// Downloads content using Linux bash-based approach
        /// </summary>
        /// <param name="url">The URL to download from</param>
        /// <param name="path">The local path where the content should be saved</param>
        /// <returns>The path where the content was actually saved</returns>
        public override async Task<string> Download(string url, string path)
        {
            // Ensure dependencies are available before attempting download
            await EnsureDependenciesAsync();
            
            return await DownloadOnLinux(url, path);
        }

        /// <summary>
        /// Prepares the file path for Linux by handling Linux-specific path requirements
        /// </summary>
        /// <param name="path">The original file path</param>
        /// <returns>The sanitized file path</returns>
        protected override string PrepareFilePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                return path;

            // Call base implementation first for common sanitization (spaces, quotes, etc.)
            var sanitized = base.PrepareFilePath(path);
            
            // Linux-specific path handling - handle special characters that need escaping
            var linuxProcessed = sanitized
                .Replace("(", "\\(")    // Escape parentheses
                .Replace(")", "\\)")
                .Replace("[", "\\[")    // Escape square brackets
                .Replace("]", "\\]")
                .Replace("{", "\\{")    // Escape curly braces
                .Replace("}", "\\}")
                .Replace("&", "\\&")    // Escape ampersand
                .Replace(";", "\\;")    // Escape semicolon
                .Replace("`", "\\`")    // Escape backticks
                .Replace("$", "\\$")    // Escape dollar signs
                .Replace("!", "\\!")    // Escape exclamation marks
                .Replace("~", "\\~");   // Escape tilde
            
            // Normalize path separators for Linux (use forward slashes)
            // Replace backslashes that aren't escape characters
            var result = "";
            for (int i = 0; i < linuxProcessed.Length; i++)
            {
                if (linuxProcessed[i] == '\\')
                {
                    // Check if this is an escape character
                    if (i + 1 < linuxProcessed.Length && 
                        ("()[]{};&`$!~".Contains(linuxProcessed[i + 1])))
                    {
                        // Keep the escape sequence
                        result += linuxProcessed[i];
                    }
                    else
                    {
                        // Convert to forward slash
                        result += "/";
                    }
                }
                else
                {
                    result += linuxProcessed[i];
                }
            }

            // Ensure the path doesn't start with special characters that could be problematic
            if (result.StartsWith("-"))
            {
                result = "_" + result.Substring(1);
            }

            return result;
        }

        private async Task<string> DownloadOnLinux(string url, string path)
        {
            var startTime = DateTime.UtcNow;
            var platform = OSPlatform.Linux;
            
            try
            {
                path = PrepareFilePath(path);
                url = CleanUrl(url);
                
                _downloadLogger.LogDownloadStart(platform, url, path);

                var fInfo = new FileInfo(path);
                var fileName = fInfo.FullName.Replace(fInfo.Extension, "");

                var proxyStr = !_config.UseProxy ? "" : ProxyManager.GetProxyString();
                _downloadLogger.LogProxyUsage(platform, proxyStr, _config.UseProxy);

                var finalScript = _scriptManager.GetDownloadScript(platform, url, fileName, proxyStr);
                var workingDirectory = Path.Combine(Directory.GetCurrentDirectory(), "Assets");

                _downloadLogger.LogScriptExecution(platform, finalScript, workingDirectory);

                var processStartInfo = new ProcessStartInfo
                {
                    FileName = "/bin/bash",
                    Arguments = $"-c \"{finalScript.Replace("\"", "\\\"")}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    WorkingDirectory = workingDirectory
                };

                using var process = new Process();
                process.StartInfo = processStartInfo;
                
                var scriptStartTime = DateTime.UtcNow;
                process.Start();
                await process.WaitForExitAsync();
                var scriptDuration = DateTime.UtcNow - scriptStartTime;
                
                string output = process.StandardOutput.ReadToEnd();
                string error = process.StandardError.ReadToEnd();
                
                _downloadLogger.LogScriptResult(platform, process.ExitCode, output, error, scriptDuration);

                if (process.ExitCode != 0)
                {
                    var scriptException = new ScriptExecutionException(platform, finalScript, output, error, process.ExitCode);
                    
                    // Attempt error recovery
                    if (_errorRecoveryService.IsRecoverable(scriptException))
                    {
                        _downloadLogger.LogErrorRecovery(platform, scriptException, "Attempting script execution recovery", false);
                        var recovered = await _errorRecoveryService.TryRecoverFromScriptExecutionAsync(scriptException);
                        
                        if (recovered)
                        {
                            _downloadLogger.LogErrorRecovery(platform, scriptException, "Script execution recovery", true);
                            // Retry the download after recovery
                            return await DownloadOnLinux(url, path);
                        }
                    }

                    var troubleshootingInfo = _errorRecoveryService.GetTroubleshootingInfo(scriptException);
                    _downloadLogger.LogTroubleshootingInfo(scriptException, troubleshootingInfo);
                    
                    throw scriptException;
                }

                var finalPath = HandleFileMoving(fileName, path);
                var totalDuration = DateTime.UtcNow - startTime;
                
                _downloadLogger.LogDownloadSuccess(platform, url, finalPath, totalDuration);
                return finalPath;
            }
            catch (Exception ex) when (!(ex is PlatformSpecificException))
            {
                var totalDuration = DateTime.UtcNow - startTime;
                _downloadLogger.LogDownloadFailure(platform, url, path, ex);
                
                // Wrap non-platform-specific exceptions for consistency
                throw new ScriptExecutionException(platform, "Download operation failed", "", ex.Message, -1, ex);
            }
        }

        /// <summary>
        /// Ensures all required Linux dependencies are available
        /// </summary>
        /// <returns>Task representing the dependency check operation</returns>
        private async Task EnsureDependenciesAsync()
        {
            var platform = OSPlatform.Linux;
            
            try
            {
                var dependenciesAvailable = await _dependencyManager.CheckDependenciesAsync();
                
                if (!dependenciesAvailable)
                {
                    // Get detailed status of individual dependencies
                    var status = await _dependencyManager.GetDependencyStatusAsync();
                    
                    // Log dependency status
                    foreach (var dependency in status)
                    {
                        _downloadLogger.LogDependencyCheck(platform, dependency.Key, dependency.Value);
                    }
                    
                    // Try to install missing dependencies
                    var installResults = await _dependencyManager.InstallMissingDependenciesAsync();
                    
                    // Check if critical dependencies are still missing
                    if (!installResults.ContainsKey("yt-dlp") || !installResults["yt-dlp"])
                    {
                        var errorMessage = await _dependencyManager.GetMissingDependenciesErrorAsync();
                        var exception = new DependencyException(platform, "yt-dlp", 
                            "Critical dependency yt-dlp is missing", errorMessage);
                        
                        var troubleshootingInfo = _errorRecoveryService.GetTroubleshootingInfo(exception);
                        _downloadLogger.LogTroubleshootingInfo(exception, troubleshootingInfo);
                        
                        throw exception;
                    }
                    
                    // Warn about ffmpeg if it's missing but don't fail
                    if (!installResults.ContainsKey("ffmpeg") || !installResults["ffmpeg"])
                    {
                        var packageManager = await _dependencyManager.DetectPackageManagerAsync();
                        var ffmpegInstructions = GetFfmpegInstallationInstructions(packageManager);
                        
                        _downloadLogger.LogDependencyCheck(platform, "ffmpeg", false);
                        
                        var ffmpegException = new DependencyException(platform, "ffmpeg", 
                            "Optional dependency ffmpeg is missing", ffmpegInstructions);
                        
                        // Try recovery for ffmpeg
                        var recovered = await _errorRecoveryService.TryRecoverFromDependencyAsync(ffmpegException);
                        _downloadLogger.LogErrorRecovery(platform, ffmpegException, "ffmpeg installation", recovered);
                        
                        if (!recovered)
                        {
                            // Log warning but don't fail
                            _downloadLogger.LogDependencyCheck(platform, "ffmpeg", false);
                        }
                    }
                }
                else
                {
                    // Log successful dependency checks
                    var status = await _dependencyManager.GetDependencyStatusAsync();
                    foreach (var dependency in status)
                    {
                        _downloadLogger.LogDependencyCheck(platform, dependency.Key, dependency.Value);
                    }
                }
            }
            catch (Exception ex) when (!(ex is DependencyException))
            {
                var errorMessage = await _dependencyManager.GetMissingDependenciesErrorAsync();
                var dependencyException = new DependencyException(platform, "unknown", 
                    $"Failed to check or install dependencies: {ex.Message}", errorMessage, ex);
                
                var troubleshootingInfo = _errorRecoveryService.GetTroubleshootingInfo(dependencyException);
                _downloadLogger.LogTroubleshootingInfo(dependencyException, troubleshootingInfo);
                
                throw dependencyException;
            }
        }

        /// <summary>
        /// Gets installation instructions specifically for ffmpeg
        /// </summary>
        /// <param name="packageManager">The detected package manager</param>
        /// <returns>Installation instructions for ffmpeg</returns>
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