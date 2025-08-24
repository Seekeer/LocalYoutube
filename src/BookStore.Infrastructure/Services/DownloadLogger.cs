using System;
using System.Runtime.InteropServices;
using BookStore.Domain.Exceptions;
using BookStore.Domain.Interfaces;
using Microsoft.Extensions.Logging;

namespace BookStore.Infrastructure.Services
{
    /// <summary>
    /// Specialized logger for download operations with platform context
    /// </summary>
    public class DownloadLogger : IDownloadLogger
    {
        private readonly ILogger<DownloadLogger> _logger;

        public DownloadLogger(ILogger<DownloadLogger> logger)
        {
            _logger = logger;
        }

        /// <summary>
        /// Logs the start of a download operation
        /// </summary>
        public void LogDownloadStart(OSPlatform platform, string url, string targetPath)
        {
            _logger.LogInformation("Starting download on {Platform}: URL={Url}, Target={TargetPath}", 
                platform, SanitizeUrl(url), targetPath);
        }

        /// <summary>
        /// Logs successful completion of a download operation
        /// </summary>
        public void LogDownloadSuccess(OSPlatform platform, string url, string finalPath, TimeSpan duration)
        {
            _logger.LogInformation("Download completed successfully on {Platform}: URL={Url}, FinalPath={FinalPath}, Duration={Duration}ms", 
                platform, SanitizeUrl(url), finalPath, duration.TotalMilliseconds);
        }

        /// <summary>
        /// Logs a failed download operation with detailed context
        /// </summary>
        public void LogDownloadFailure(OSPlatform platform, string url, string targetPath, Exception exception, 
            string standardOutput = null, string standardError = null)
        {
            var logLevel = exception is PlatformSpecificException ? LogLevel.Warning : LogLevel.Error;
            
            _logger.Log(logLevel, exception, 
                "Download failed on {Platform}: URL={Url}, Target={TargetPath}, Error={ErrorMessage}", 
                platform, SanitizeUrl(url), targetPath, exception.Message);

            if (!string.IsNullOrEmpty(standardOutput))
            {
                _logger.LogDebug("Download StandardOutput on {Platform}: {StandardOutput}", platform, standardOutput);
            }

            if (!string.IsNullOrEmpty(standardError))
            {
                _logger.LogWarning("Download StandardError on {Platform}: {StandardError}", platform, standardError);
            }

            // Log additional context for platform-specific exceptions
            if (exception is PlatformSpecificException platformEx)
            {
                LogPlatformSpecificExceptionDetails(platformEx);
            }
        }

        /// <summary>
        /// Logs script execution details
        /// </summary>
        public void LogScriptExecution(OSPlatform platform, string scriptContent, string workingDirectory)
        {
            _logger.LogDebug("Executing script on {Platform}: WorkingDir={WorkingDirectory}, ScriptLength={ScriptLength}", 
                platform, workingDirectory, scriptContent?.Length ?? 0);
            
            // Log script content at trace level for debugging
            _logger.LogTrace("Script content on {Platform}: {ScriptContent}", platform, scriptContent);
        }

        /// <summary>
        /// Logs script execution results
        /// </summary>
        public void LogScriptResult(OSPlatform platform, int exitCode, string standardOutput, string standardError, TimeSpan duration)
        {
            var logLevel = exitCode == 0 ? LogLevel.Debug : LogLevel.Warning;
            
            _logger.Log(logLevel, "Script execution completed on {Platform}: ExitCode={ExitCode}, Duration={Duration}ms", 
                platform, exitCode, duration.TotalMilliseconds);

            if (!string.IsNullOrEmpty(standardOutput))
            {
                _logger.LogDebug("Script StandardOutput on {Platform}: {StandardOutput}", platform, standardOutput);
            }

            if (!string.IsNullOrEmpty(standardError))
            {
                var errorLogLevel = exitCode == 0 ? LogLevel.Debug : LogLevel.Warning;
                _logger.Log(errorLogLevel, "Script StandardError on {Platform}: {StandardError}", platform, standardError);
            }
        }

        /// <summary>
        /// Logs dependency check results
        /// </summary>
        public void LogDependencyCheck(OSPlatform platform, string dependencyName, bool isAvailable, 
            string version = null, string location = null)
        {
            if (isAvailable)
            {
                _logger.LogInformation("Dependency check on {Platform}: {DependencyName} is available (Version: {Version}, Location: {Location})", 
                    platform, dependencyName, version ?? "Unknown", location ?? "Unknown");
            }
            else
            {
                _logger.LogWarning("Dependency check on {Platform}: {DependencyName} is NOT available", 
                    platform, dependencyName);
            }
        }

        /// <summary>
        /// Logs file operation attempts
        /// </summary>
        public void LogFileOperation(OSPlatform platform, string operation, string filePath, bool success, string errorMessage = null)
        {
            if (success)
            {
                _logger.LogDebug("File operation succeeded on {Platform}: {Operation} on {FilePath}", 
                    platform, operation, filePath);
            }
            else
            {
                _logger.LogWarning("File operation failed on {Platform}: {Operation} on {FilePath}, Error: {ErrorMessage}", 
                    platform, operation, filePath, errorMessage ?? "Unknown error");
            }
        }

        /// <summary>
        /// Logs error recovery attempts
        /// </summary>
        public void LogErrorRecovery(OSPlatform platform, Exception exception, string recoveryAction, bool success)
        {
            if (success)
            {
                _logger.LogInformation("Error recovery succeeded on {Platform}: {RecoveryAction} for {ExceptionType}", 
                    platform, recoveryAction, exception.GetType().Name);
            }
            else
            {
                _logger.LogWarning("Error recovery failed on {Platform}: {RecoveryAction} for {ExceptionType} - {ErrorMessage}", 
                    platform, recoveryAction, exception.GetType().Name, exception.Message);
            }
        }

        /// <summary>
        /// Logs platform-specific troubleshooting information
        /// </summary>
        public void LogTroubleshootingInfo(PlatformSpecificException exception, string troubleshootingInfo)
        {
            _logger.LogInformation("Troubleshooting information for {ExceptionType} on {Platform}:\n{TroubleshootingInfo}", 
                exception.GetType().Name, exception.PlatformName, troubleshootingInfo);
        }

        /// <summary>
        /// Logs proxy configuration usage
        /// </summary>
        public void LogProxyUsage(OSPlatform platform, string proxyString, bool isEnabled)
        {
            if (isEnabled)
            {
                _logger.LogInformation("Proxy enabled on {Platform}: {ProxyInfo}", 
                    platform, SanitizeProxyString(proxyString));
            }
            else
            {
                _logger.LogDebug("Proxy disabled on {Platform}", platform);
            }
        }

        /// <summary>
        /// Logs additional details for platform-specific exceptions
        /// </summary>
        private void LogPlatformSpecificExceptionDetails(PlatformSpecificException exception)
        {
            switch (exception)
            {
                case MissingExecutableException missingExec:
                    _logger.LogWarning("Missing executable on {Platform}: {ExecutableName}. Installation instructions: {Instructions}", 
                        exception.PlatformName, missingExec.ExecutableName, missingExec.InstallationInstructions);
                    break;

                case ScriptExecutionException scriptExec:
                    _logger.LogWarning("Script execution failed on {Platform}: ExitCode={ExitCode}, StdErr={StandardError}", 
                        exception.PlatformName, scriptExec.ExitCode, scriptExec.StandardError);
                    break;

                case PlatformFileOperationException fileOp:
                    _logger.LogWarning("File operation failed on {Platform}: {Operation} on {FilePath}", 
                        exception.PlatformName, fileOp.Operation, fileOp.FilePath);
                    break;

                case DependencyException depExc:
                    _logger.LogWarning("Dependency issue on {Platform}: {DependencyName}. Recommended action: {RecommendedAction}", 
                        exception.PlatformName, depExc.DependencyName, depExc.RecommendedAction);
                    break;
            }
        }

        /// <summary>
        /// Sanitizes URL for logging by removing sensitive information
        /// </summary>
        private string SanitizeUrl(string url)
        {
            if (string.IsNullOrEmpty(url))
                return url;

            try
            {
                var uri = new Uri(url);
                // Remove query parameters that might contain sensitive information
                return $"{uri.Scheme}://{uri.Host}{uri.AbsolutePath}";
            }
            catch
            {
                // If URL parsing fails, just return a generic placeholder
                return "[URL]";
            }
        }

        /// <summary>
        /// Sanitizes proxy string for logging by removing credentials
        /// </summary>
        private string SanitizeProxyString(string proxyString)
        {
            if (string.IsNullOrEmpty(proxyString))
                return proxyString;

            try
            {
                // Remove credentials from proxy string for logging
                if (proxyString.Contains("@"))
                {
                    var parts = proxyString.Split('@');
                    if (parts.Length == 2)
                    {
                        return $"[credentials]@{parts[1]}";
                    }
                }
                return proxyString;
            }
            catch
            {
                return "[proxy]";
            }
        }
    }
}