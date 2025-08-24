using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using BookStore.Domain.Exceptions;
using BookStore.Domain.Interfaces;
using Microsoft.Extensions.Logging;

namespace BookStore.Infrastructure.Services
{
    /// <summary>
    /// Service for handling error recovery mechanisms for platform-specific issues
    /// </summary>
    public class ErrorRecoveryService : IErrorRecoveryService
    {
        private readonly ILogger<ErrorRecoveryService> _logger;
        private readonly ILinuxDependencyManager _linuxDependencyManager;
        private readonly IPlatformDetectionService _platformDetectionService;

        public ErrorRecoveryService(
            ILogger<ErrorRecoveryService> logger,
            ILinuxDependencyManager linuxDependencyManager,
            IPlatformDetectionService platformDetectionService)
        {
            _logger = logger;
            _linuxDependencyManager = linuxDependencyManager;
            _platformDetectionService = platformDetectionService;
        }

        /// <summary>
        /// Attempts to recover from a missing executable error
        /// </summary>
        public async Task<bool> TryRecoverFromMissingExecutableAsync(MissingExecutableException exception)
        {
            _logger.LogInformation("Attempting to recover from missing executable: {ExecutableName} on {Platform}", 
                exception.ExecutableName, exception.PlatformName);

            try
            {
                if (exception.Platform == OSPlatform.Linux)
                {
                    // Try to install the missing executable using the dependency manager
                    var installResults = await _linuxDependencyManager.InstallMissingDependenciesAsync();
                    
                    if (installResults.ContainsKey(exception.ExecutableName) && installResults[exception.ExecutableName])
                    {
                        _logger.LogInformation("Successfully recovered from missing executable: {ExecutableName}", 
                            exception.ExecutableName);
                        return true;
                    }
                }
                else if (exception.Platform == OSPlatform.Windows)
                {
                    // For Windows, we typically bundle executables, so this might be a deployment issue
                    var assetsPath = Path.Combine(Directory.GetCurrentDirectory(), "Assets");
                    var executablePath = Path.Combine(assetsPath, exception.ExecutableName);
                    
                    if (File.Exists(executablePath))
                    {
                        _logger.LogInformation("Found executable in Assets directory: {ExecutablePath}", executablePath);
                        return true;
                    }
                    
                    // Check if it's in PATH
                    var pathExecutable = FindExecutableInPath(exception.ExecutableName);
                    if (!string.IsNullOrEmpty(pathExecutable))
                    {
                        _logger.LogInformation("Found executable in PATH: {ExecutablePath}", pathExecutable);
                        return true;
                    }
                }

                _logger.LogWarning("Could not recover from missing executable: {ExecutableName}", exception.ExecutableName);
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while trying to recover from missing executable: {ExecutableName}", 
                    exception.ExecutableName);
                return false;
            }
        }

        /// <summary>
        /// Attempts to recover from a script execution error
        /// </summary>
        public async Task<bool> TryRecoverFromScriptExecutionAsync(ScriptExecutionException exception)
        {
            _logger.LogInformation("Attempting to recover from script execution error on {Platform} with exit code {ExitCode}", 
                exception.PlatformName, exception.ExitCode);

            try
            {
                // Common recovery strategies based on error patterns
                if (exception.StandardError.Contains("command not found") || 
                    exception.StandardError.Contains("is not recognized as an internal or external command"))
                {
                    // This is likely a missing executable issue
                    var executableName = ExtractExecutableNameFromError(exception.StandardError);
                    if (!string.IsNullOrEmpty(executableName))
                    {
                        var missingExecException = new MissingExecutableException(
                            exception.Platform, 
                            executableName, 
                            GetInstallationInstructions(exception.Platform, executableName));
                        
                        return await TryRecoverFromMissingExecutableAsync(missingExecException);
                    }
                }

                if (exception.StandardError.Contains("Permission denied") || 
                    exception.StandardError.Contains("Access is denied"))
                {
                    // This is a permission issue - we can't automatically fix this but can provide guidance
                    _logger.LogWarning("Script execution failed due to permission issues. Manual intervention required.");
                    return false;
                }

                if (exception.StandardError.Contains("No space left on device") || 
                    exception.StandardError.Contains("disk full"))
                {
                    // Disk space issue - can't automatically recover
                    _logger.LogError("Script execution failed due to insufficient disk space.");
                    return false;
                }

                // For network-related errors, we might want to retry
                if (exception.StandardError.Contains("network") || 
                    exception.StandardError.Contains("timeout") ||
                    exception.StandardError.Contains("connection"))
                {
                    _logger.LogInformation("Script execution failed due to network issues. This might be recoverable with retry.");
                    // Return false here as the caller should handle retries
                    return false;
                }

                _logger.LogWarning("Could not determine recovery strategy for script execution error");
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while trying to recover from script execution error");
                return false;
            }
        }

        /// <summary>
        /// Attempts to recover from a file operation error
        /// </summary>
        public async Task<bool> TryRecoverFromFileOperationAsync(PlatformFileOperationException exception)
        {
            _logger.LogInformation("Attempting to recover from file operation error: {Operation} on {FilePath} ({Platform})", 
                exception.Operation, exception.FilePath, exception.PlatformName);

            try
            {
                switch (exception.Operation.ToLowerInvariant())
                {
                    case "create":
                    case "write":
                        // Try to create the directory if it doesn't exist
                        var directory = Path.GetDirectoryName(exception.FilePath);
                        if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                        {
                            Directory.CreateDirectory(directory);
                            _logger.LogInformation("Created missing directory: {Directory}", directory);
                            return true;
                        }
                        break;

                    case "move":
                    case "copy":
                        // Check if source file exists and destination directory exists
                        if (File.Exists(exception.FilePath))
                        {
                            var destDir = Path.GetDirectoryName(exception.FilePath);
                            if (!string.IsNullOrEmpty(destDir) && !Directory.Exists(destDir))
                            {
                                Directory.CreateDirectory(destDir);
                                _logger.LogInformation("Created missing destination directory: {Directory}", destDir);
                                return true;
                            }
                        }
                        break;

                    case "delete":
                        // If file doesn't exist, consider it a successful delete
                        if (!File.Exists(exception.FilePath))
                        {
                            _logger.LogInformation("File already deleted or doesn't exist: {FilePath}", exception.FilePath);
                            return true;
                        }
                        break;
                }

                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while trying to recover from file operation error");
                return false;
            }
        }

        /// <summary>
        /// Attempts to recover from a dependency error
        /// </summary>
        public async Task<bool> TryRecoverFromDependencyAsync(DependencyException exception)
        {
            _logger.LogInformation("Attempting to recover from dependency error: {DependencyName} on {Platform}", 
                exception.DependencyName, exception.PlatformName);

            try
            {
                if (exception.Platform == OSPlatform.Linux)
                {
                    // Use the dependency manager to try installing the missing dependency
                    var installResults = await _linuxDependencyManager.InstallMissingDependenciesAsync();
                    
                    if (installResults.ContainsKey(exception.DependencyName) && installResults[exception.DependencyName])
                    {
                        _logger.LogInformation("Successfully recovered from dependency error: {DependencyName}", 
                            exception.DependencyName);
                        return true;
                    }
                }

                _logger.LogWarning("Could not recover from dependency error: {DependencyName}", exception.DependencyName);
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while trying to recover from dependency error: {DependencyName}", 
                    exception.DependencyName);
                return false;
            }
        }

        /// <summary>
        /// Gets detailed troubleshooting information for a platform-specific exception
        /// </summary>
        public string GetTroubleshootingInfo(PlatformSpecificException exception)
        {
            var troubleshooting = $"Platform: {exception.PlatformName}\n";
            troubleshooting += $"Error: {exception.Message}\n\n";

            switch (exception)
            {
                case MissingExecutableException missingExec:
                    troubleshooting += "Troubleshooting Steps:\n";
                    troubleshooting += $"1. Install the missing executable: {missingExec.ExecutableName}\n";
                    troubleshooting += $"2. Installation instructions:\n{missingExec.InstallationInstructions}\n";
                    troubleshooting += "3. Ensure the executable is in your system PATH\n";
                    troubleshooting += "4. Restart the application after installation\n";
                    break;

                case ScriptExecutionException scriptExec:
                    troubleshooting += "Troubleshooting Steps:\n";
                    troubleshooting += $"1. Check the error output: {scriptExec.StandardError}\n";
                    troubleshooting += $"2. Verify all required executables are installed\n";
                    troubleshooting += "3. Check file permissions in the working directory\n";
                    troubleshooting += "4. Ensure sufficient disk space is available\n";
                    if (!string.IsNullOrEmpty(scriptExec.StandardOutput))
                    {
                        troubleshooting += $"5. Review standard output: {scriptExec.StandardOutput}\n";
                    }
                    break;

                case PlatformFileOperationException fileOp:
                    troubleshooting += "Troubleshooting Steps:\n";
                    troubleshooting += $"1. Check file permissions for: {fileOp.FilePath}\n";
                    troubleshooting += "2. Ensure the directory exists and is writable\n";
                    troubleshooting += "3. Check available disk space\n";
                    troubleshooting += "4. Verify the file path is valid for your platform\n";
                    break;

                case DependencyException depExc:
                    troubleshooting += "Troubleshooting Steps:\n";
                    troubleshooting += $"1. Install the missing dependency: {depExc.DependencyName}\n";
                    troubleshooting += $"2. Recommended action: {depExc.RecommendedAction}\n";
                    troubleshooting += "3. Update your package manager cache\n";
                    troubleshooting += "4. Check your internet connection\n";
                    break;
            }

            return troubleshooting;
        }

        /// <summary>
        /// Checks if an error is recoverable
        /// </summary>
        public bool IsRecoverable(Exception exception)
        {
            return exception switch
            {
                MissingExecutableException => true,
                DependencyException => true,
                ScriptExecutionException scriptEx => IsScriptErrorRecoverable(scriptEx),
                PlatformFileOperationException fileEx => IsFileErrorRecoverable(fileEx),
                _ => false
            };
        }

        private bool IsScriptErrorRecoverable(ScriptExecutionException exception)
        {
            // Network errors might be recoverable with retry
            if (exception.StandardError.Contains("network") || 
                exception.StandardError.Contains("timeout") ||
                exception.StandardError.Contains("connection"))
            {
                return true;
            }

            // Missing command errors are recoverable if we can install the command
            if (exception.StandardError.Contains("command not found") || 
                exception.StandardError.Contains("is not recognized as an internal or external command"))
            {
                return true;
            }

            // Permission and disk space errors are not automatically recoverable
            return false;
        }

        private bool IsFileErrorRecoverable(PlatformFileOperationException exception)
        {
            // Directory creation issues are often recoverable
            if (exception.Operation.ToLowerInvariant() is "create" or "write" or "move" or "copy")
            {
                return true;
            }

            // Delete operations where file doesn't exist are "recoverable"
            if (exception.Operation.ToLowerInvariant() == "delete")
            {
                return true;
            }

            return false;
        }

        private string ExtractExecutableNameFromError(string errorOutput)
        {
            // Try to extract executable name from common error patterns
            if (errorOutput.Contains("command not found"))
            {
                // Linux: "bash: yt-dlp: command not found"
                var parts = errorOutput.Split(':');
                if (parts.Length >= 2)
                {
                    return parts[1].Trim();
                }
            }
            else if (errorOutput.Contains("is not recognized as an internal or external command"))
            {
                // Windows: "'yt-dlp' is not recognized as an internal or external command"
                var startQuote = errorOutput.IndexOf('\'');
                var endQuote = errorOutput.IndexOf('\'', startQuote + 1);
                if (startQuote >= 0 && endQuote > startQuote)
                {
                    return errorOutput.Substring(startQuote + 1, endQuote - startQuote - 1);
                }
            }

            return string.Empty;
        }

        private string GetInstallationInstructions(OSPlatform platform, string executableName)
        {
            if (platform == OSPlatform.Linux)
            {
                return executableName switch
                {
                    "yt-dlp" => "Install with: pip3 install yt-dlp or use your package manager",
                    "ffmpeg" => "Install with your package manager (e.g., sudo apt install ffmpeg)",
                    _ => $"Install {executableName} using your system's package manager"
                };
            }
            else if (platform == OSPlatform.Windows)
            {
                return executableName switch
                {
                    "yt-dlp.exe" => "Download from https://github.com/yt-dlp/yt-dlp/releases and place in Assets folder",
                    "ffmpeg.exe" => "Download from https://ffmpeg.org/download.html and place in Assets folder",
                    _ => $"Download {executableName} and ensure it's in your PATH or Assets folder"
                };
            }

            return $"Install {executableName} for your platform";
        }

        private string FindExecutableInPath(string executableName)
        {
            var pathVariable = Environment.GetEnvironmentVariable("PATH");
            if (string.IsNullOrEmpty(pathVariable))
                return string.Empty;

            var paths = pathVariable.Split(Path.PathSeparator);
            foreach (var path in paths)
            {
                var fullPath = Path.Combine(path, executableName);
                if (File.Exists(fullPath))
                    return fullPath;
            }

            return string.Empty;
        }
    }
}