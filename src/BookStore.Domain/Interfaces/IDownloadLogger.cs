using System;
using System.Runtime.InteropServices;
using BookStore.Domain.Exceptions;

namespace BookStore.Domain.Interfaces
{
    /// <summary>
    /// Specialized logger for download operations with platform context
    /// </summary>
    public interface IDownloadLogger
    {
        /// <summary>
        /// Logs the start of a download operation
        /// </summary>
        /// <param name="platform">The platform where the download is occurring</param>
        /// <param name="url">The URL being downloaded</param>
        /// <param name="targetPath">The target file path</param>
        void LogDownloadStart(OSPlatform platform, string url, string targetPath);

        /// <summary>
        /// Logs successful completion of a download operation
        /// </summary>
        /// <param name="platform">The platform where the download occurred</param>
        /// <param name="url">The URL that was downloaded</param>
        /// <param name="finalPath">The final file path where content was saved</param>
        /// <param name="duration">The duration of the download operation</param>
        void LogDownloadSuccess(OSPlatform platform, string url, string finalPath, TimeSpan duration);

        /// <summary>
        /// Logs a failed download operation with detailed context
        /// </summary>
        /// <param name="platform">The platform where the download failed</param>
        /// <param name="url">The URL that failed to download</param>
        /// <param name="targetPath">The intended target file path</param>
        /// <param name="exception">The exception that caused the failure</param>
        /// <param name="standardOutput">Standard output from the download process</param>
        /// <param name="standardError">Standard error from the download process</param>
        void LogDownloadFailure(OSPlatform platform, string url, string targetPath, Exception exception, 
            string standardOutput = null, string standardError = null);

        /// <summary>
        /// Logs script execution details
        /// </summary>
        /// <param name="platform">The platform where the script is executing</param>
        /// <param name="scriptContent">The content of the script being executed</param>
        /// <param name="workingDirectory">The working directory for script execution</param>
        void LogScriptExecution(OSPlatform platform, string scriptContent, string workingDirectory);

        /// <summary>
        /// Logs script execution results
        /// </summary>
        /// <param name="platform">The platform where the script executed</param>
        /// <param name="exitCode">The exit code from script execution</param>
        /// <param name="standardOutput">Standard output from the script</param>
        /// <param name="standardError">Standard error from the script</param>
        /// <param name="duration">The duration of script execution</param>
        void LogScriptResult(OSPlatform platform, int exitCode, string standardOutput, string standardError, TimeSpan duration);

        /// <summary>
        /// Logs dependency check results
        /// </summary>
        /// <param name="platform">The platform where dependencies were checked</param>
        /// <param name="dependencyName">The name of the dependency</param>
        /// <param name="isAvailable">Whether the dependency is available</param>
        /// <param name="version">The version of the dependency (if available)</param>
        /// <param name="location">The location where the dependency was found</param>
        void LogDependencyCheck(OSPlatform platform, string dependencyName, bool isAvailable, 
            string version = null, string location = null);

        /// <summary>
        /// Logs file operation attempts
        /// </summary>
        /// <param name="platform">The platform where the file operation is occurring</param>
        /// <param name="operation">The type of file operation (create, move, delete, etc.)</param>
        /// <param name="filePath">The file path involved in the operation</param>
        /// <param name="success">Whether the operation was successful</param>
        /// <param name="errorMessage">Error message if the operation failed</param>
        void LogFileOperation(OSPlatform platform, string operation, string filePath, bool success, string errorMessage = null);

        /// <summary>
        /// Logs error recovery attempts
        /// </summary>
        /// <param name="platform">The platform where recovery is being attempted</param>
        /// <param name="exception">The original exception being recovered from</param>
        /// <param name="recoveryAction">The recovery action being taken</param>
        /// <param name="success">Whether the recovery was successful</param>
        void LogErrorRecovery(OSPlatform platform, Exception exception, string recoveryAction, bool success);

        /// <summary>
        /// Logs platform-specific troubleshooting information
        /// </summary>
        /// <param name="exception">The platform-specific exception</param>
        /// <param name="troubleshootingInfo">Detailed troubleshooting information</param>
        void LogTroubleshootingInfo(PlatformSpecificException exception, string troubleshootingInfo);

        /// <summary>
        /// Logs proxy configuration usage
        /// </summary>
        /// <param name="platform">The platform where proxy is being used</param>
        /// <param name="proxyString">The proxy configuration string (sanitized)</param>
        /// <param name="isEnabled">Whether proxy is enabled</param>
        void LogProxyUsage(OSPlatform platform, string proxyString, bool isEnabled);
    }
}