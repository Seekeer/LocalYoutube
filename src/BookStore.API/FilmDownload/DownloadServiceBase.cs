using BookStore.Domain.Interfaces;
using BookStore.Domain.Exceptions;
using FileStore.Domain;
using Infrastructure;
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

namespace API.FilmDownload
{
    /// <summary>
    /// Abstract base class for download services providing common functionality
    /// </summary>
    public abstract class DownloadServiceBase : IDownloadService
    {
        protected readonly AppConfig _config;

        protected DownloadServiceBase(AppConfig config)
        {
            _config = config;
        }

        /// <summary>
        /// Downloads content from the specified URL to the given path
        /// </summary>
        /// <param name="url">The URL to download from</param>
        /// <param name="path">The local path where the content should be saved</param>
        /// <returns>The path where the content was actually saved</returns>
        public abstract Task<string> Download(string url, string path);

        /// <summary>
        /// Prepares the file path by removing problematic characters
        /// </summary>
        /// <param name="path">The original file path</param>
        /// <returns>The sanitized file path</returns>
        protected virtual string PrepareFilePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                return path;

            // Common sanitization for all platforms
            var sanitized = path
                .Replace(" ", "")  // Remove spaces
                .Replace("'", "")  // Remove single quotes (breaks PowerShell)
                .Replace("\"", "") // Remove double quotes
                .Replace("\t", "") // Remove tabs
                .Replace("\n", "") // Remove newlines
                .Replace("\r", ""); // Remove carriage returns

            // Remove other problematic characters that could cause issues across platforms
            // But preserve path separators for platform-specific handling
            sanitized = sanitized
                .Replace(":", "_")   // Colons can be problematic in filenames
                .Replace("*", "_")   // Asterisks are wildcards
                .Replace("?", "_")   // Question marks are wildcards
                .Replace("<", "_")   // Less than
                .Replace(">", "_")   // Greater than
                .Replace("|", "_");  // Pipe character

            return sanitized;
        }

        /// <summary>
        /// Cleans the URL by removing unwanted parameters
        /// </summary>
        /// <param name="url">The original URL</param>
        /// <returns>The cleaned URL</returns>
        protected virtual string CleanUrl(string url)
        {
            return url.ClearEnd("&list=");
        }

        /// <summary>
        /// Handles file moving logic after download completion with comprehensive error handling
        /// </summary>
        /// <param name="downloadedFileName">The name of the downloaded file</param>
        /// <param name="targetPath">The target path where the file should be moved</param>
        /// <returns>The final path of the moved file</returns>
        protected virtual string HandleFileMoving(string downloadedFileName, string targetPath)
        {
            var platform = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? OSPlatform.Windows : OSPlatform.Linux;
            
            try
            {
                return TryMoveFile(downloadedFileName, targetPath, platform) ??
                       TryMoveFile(downloadedFileName + "#", targetPath, platform) ??
                       TryMoveFile(downloadedFileName + ".mp4", targetPath, platform) ??
                       targetPath;
            }
            catch (Exception ex)
            {
                throw new PlatformFileOperationException(platform, targetPath, "move", 
                    $"Failed to move downloaded file from {downloadedFileName} to {targetPath}", ex);
            }
        }

        /// <summary>
        /// Attempts to move a file with proper error handling
        /// </summary>
        /// <param name="sourcePath">The source file path</param>
        /// <param name="targetPath">The target file path</param>
        /// <param name="platform">The current platform</param>
        /// <returns>The target path if successful, null if source doesn't exist</returns>
        private string TryMoveFile(string sourcePath, string targetPath, OSPlatform platform)
        {
            if (!File.Exists(sourcePath))
                return null;

            try
            {
                // Ensure target directory exists
                var targetDirectory = Path.GetDirectoryName(targetPath);
                if (!string.IsNullOrEmpty(targetDirectory) && !Directory.Exists(targetDirectory))
                {
                    Directory.CreateDirectory(targetDirectory);
                }

                // Remove target file if it exists
                if (File.Exists(targetPath))
                {
                    try
                    {
                        File.Delete(targetPath);
                    }
                    catch (Exception ex)
                    {
                        throw new PlatformFileOperationException(platform, targetPath, "delete", 
                            "Failed to delete existing target file before move", ex);
                    }
                }

                // Move the file
                File.Move(sourcePath, targetPath);
                return targetPath;
            }
            catch (UnauthorizedAccessException ex)
            {
                throw new PlatformFileOperationException(platform, targetPath, "move", 
                    "Access denied. Check file permissions and ensure the file is not in use", ex);
            }
            catch (DirectoryNotFoundException ex)
            {
                throw new PlatformFileOperationException(platform, targetPath, "move", 
                    "Target directory not found", ex);
            }
            catch (IOException ex)
            {
                throw new PlatformFileOperationException(platform, targetPath, "move", 
                    "I/O error occurred during file move operation", ex);
            }
        }
    }
}