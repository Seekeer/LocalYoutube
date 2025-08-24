using BookStore.Domain.Interfaces;
using BookStore.Domain.Exceptions;
using FileStore.Domain;
using Infrastructure;
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

namespace API.FilmDownload
{
    /// <summary>
    /// Windows-specific implementation of download service using PowerShell scripts
    /// </summary>
    public class WindowsDownloadService : DownloadServiceBase
    {
        private readonly IScriptManager _scriptManager;
        private readonly IDownloadLogger _downloadLogger;
        private readonly IErrorRecoveryService _errorRecoveryService;

        public WindowsDownloadService(AppConfig config, IScriptManager scriptManager, 
            IDownloadLogger downloadLogger, IErrorRecoveryService errorRecoveryService) : base(config)
        {
            _scriptManager = scriptManager;
            _downloadLogger = downloadLogger;
            _errorRecoveryService = errorRecoveryService;
        }

        /// <summary>
        /// Downloads content using Windows PowerShell-based approach
        /// </summary>
        /// <param name="url">The URL to download from</param>
        /// <param name="path">The local path where the content should be saved</param>
        /// <returns>The path where the content was actually saved</returns>
        public override async Task<string> Download(string url, string path)
        {
            return await DownloadOnWindows(url, path);
        }

        /// <summary>
        /// Prepares the file path for Windows by handling Windows-specific path requirements
        /// </summary>
        /// <param name="path">The original file path</param>
        /// <returns>The sanitized file path</returns>
        protected override string PrepareFilePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                return path;

            // Call base implementation first for common sanitization
            var sanitized = base.PrepareFilePath(path);
            
            // Windows-specific path handling
            // Remove double quotes and handle path separators
            sanitized = sanitized.Replace("\"", "");
            
            // Normalize path separators for Windows (use backslashes)
            var windowsSanitized = sanitized.Replace("/", "\\");

            // Handle Windows reserved names
            try
            {
                var fileName = Path.GetFileNameWithoutExtension(windowsSanitized);
                var extension = Path.GetExtension(windowsSanitized);
                var directory = Path.GetDirectoryName(windowsSanitized);

                // Check for Windows reserved names
                string[] reservedNames = { "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9" };
                
                if (!string.IsNullOrEmpty(fileName) && reservedNames.Contains(fileName.ToUpperInvariant()))
                {
                    fileName = "_" + fileName;
                }

                // Reconstruct the path
                if (!string.IsNullOrEmpty(directory))
                {
                    windowsSanitized = Path.Combine(directory, fileName + extension);
                }
                else
                {
                    windowsSanitized = fileName + extension;
                }

                // Ensure path length doesn't exceed Windows limits (260 characters for full path)
                if (windowsSanitized.Length > 250) // Leave some buffer for working directory
                {
                    var maxFileNameLength = Math.Max(1, 250 - (windowsSanitized.Length - fileName.Length));
                    var truncatedFileName = fileName.Length > maxFileNameLength 
                        ? fileName.Substring(0, maxFileNameLength) 
                        : fileName;
                        
                    if (!string.IsNullOrEmpty(directory))
                    {
                        windowsSanitized = Path.Combine(directory, truncatedFileName + extension);
                    }
                    else
                    {
                        windowsSanitized = truncatedFileName + extension;
                    }
                }
            }
            catch
            {
                // If path parsing fails, just return the sanitized version
                // This handles edge cases where the path might not be a valid file path
            }

            return windowsSanitized;
        }

        private async Task<string> DownloadOnWindows(string url, string path)
        {
            var startTime = DateTime.UtcNow;
            var platform = OSPlatform.Windows;
            
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

                // Verify required executables exist before attempting download
                await VerifyWindowsExecutables();

                var processStartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = $"-Command \"{finalScript}\"",
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
                            return await DownloadOnWindows(url, path);
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
        /// Verifies that required Windows executables are available
        /// </summary>
        private async Task VerifyWindowsExecutables()
        {
            var platform = OSPlatform.Windows;
            var assetsPath = Path.Combine(Directory.GetCurrentDirectory(), "Assets");
            
            // Check for yt-dlp.exe
            var ytDlpPath = Path.Combine(assetsPath, "yt-dlp.exe");
            var ytDlpExists = File.Exists(ytDlpPath);
            _downloadLogger.LogDependencyCheck(platform, "yt-dlp.exe", ytDlpExists, location: ytDlpExists ? ytDlpPath : null);
            
            if (!ytDlpExists)
            {
                var instructions = "Download yt-dlp.exe from https://github.com/yt-dlp/yt-dlp/releases and place it in the Assets folder";
                var exception = new MissingExecutableException(platform, "yt-dlp.exe", instructions);
                
                // Try recovery
                var recovered = await _errorRecoveryService.TryRecoverFromMissingExecutableAsync(exception);
                if (!recovered)
                {
                    var troubleshootingInfo = _errorRecoveryService.GetTroubleshootingInfo(exception);
                    _downloadLogger.LogTroubleshootingInfo(exception, troubleshootingInfo);
                    throw exception;
                }
            }

            // Check for ffmpeg.exe (optional but recommended)
            var ffmpegPath = Path.Combine(assetsPath, "ffmpeg.exe");
            var ffmpegExists = File.Exists(ffmpegPath);
            _downloadLogger.LogDependencyCheck(platform, "ffmpeg.exe", ffmpegExists, location: ffmpegExists ? ffmpegPath : null);
            
            if (!ffmpegExists)
            {
                // ffmpeg is optional, so just log a warning
                _downloadLogger.LogDependencyCheck(platform, "ffmpeg.exe", false);
            }
        }
    }
}