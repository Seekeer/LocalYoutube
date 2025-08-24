using System;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using BookStore.Domain.Exceptions;

namespace BookStore.Domain.Interfaces
{
    /// <summary>
    /// Service for handling error recovery mechanisms for platform-specific issues
    /// </summary>
    public interface IErrorRecoveryService
    {
        /// <summary>
        /// Attempts to recover from a missing executable error
        /// </summary>
        /// <param name="exception">The missing executable exception</param>
        /// <returns>True if recovery was successful, false otherwise</returns>
        Task<bool> TryRecoverFromMissingExecutableAsync(MissingExecutableException exception);

        /// <summary>
        /// Attempts to recover from a script execution error
        /// </summary>
        /// <param name="exception">The script execution exception</param>
        /// <returns>True if recovery was successful, false otherwise</returns>
        Task<bool> TryRecoverFromScriptExecutionAsync(ScriptExecutionException exception);

        /// <summary>
        /// Attempts to recover from a file operation error
        /// </summary>
        /// <param name="exception">The file operation exception</param>
        /// <returns>True if recovery was successful, false otherwise</returns>
        Task<bool> TryRecoverFromFileOperationAsync(PlatformFileOperationException exception);

        /// <summary>
        /// Attempts to recover from a dependency error
        /// </summary>
        /// <param name="exception">The dependency exception</param>
        /// <returns>True if recovery was successful, false otherwise</returns>
        Task<bool> TryRecoverFromDependencyAsync(DependencyException exception);

        /// <summary>
        /// Gets detailed troubleshooting information for a platform-specific exception
        /// </summary>
        /// <param name="exception">The platform-specific exception</param>
        /// <returns>Detailed troubleshooting information</returns>
        string GetTroubleshootingInfo(PlatformSpecificException exception);

        /// <summary>
        /// Checks if an error is recoverable
        /// </summary>
        /// <param name="exception">The exception to check</param>
        /// <returns>True if the error might be recoverable, false otherwise</returns>
        bool IsRecoverable(Exception exception);
    }
}