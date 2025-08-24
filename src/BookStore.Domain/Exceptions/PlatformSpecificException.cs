using System;
using System.Runtime.InteropServices;

namespace BookStore.Domain.Exceptions
{
    /// <summary>
    /// Base exception for platform-specific errors in download operations
    /// </summary>
    public abstract class PlatformSpecificException : Exception
    {
        public OSPlatform Platform { get; }
        public string PlatformName => Platform.ToString();

        protected PlatformSpecificException(OSPlatform platform, string message) : base(message)
        {
            Platform = platform;
        }

        protected PlatformSpecificException(OSPlatform platform, string message, Exception innerException) 
            : base(message, innerException)
        {
            Platform = platform;
        }
    }

    /// <summary>
    /// Exception thrown when required executables are missing for the current platform
    /// </summary>
    public class MissingExecutableException : PlatformSpecificException
    {
        public string ExecutableName { get; }
        public string InstallationInstructions { get; }

        public MissingExecutableException(OSPlatform platform, string executableName, string installationInstructions)
            : base(platform, $"Required executable '{executableName}' is missing on {platform}")
        {
            ExecutableName = executableName;
            InstallationInstructions = installationInstructions;
        }

        public MissingExecutableException(OSPlatform platform, string executableName, string installationInstructions, Exception innerException)
            : base(platform, $"Required executable '{executableName}' is missing on {platform}", innerException)
        {
            ExecutableName = executableName;
            InstallationInstructions = installationInstructions;
        }
    }

    /// <summary>
    /// Exception thrown when script execution fails on a specific platform
    /// </summary>
    public class ScriptExecutionException : PlatformSpecificException
    {
        public string ScriptContent { get; }
        public string StandardOutput { get; }
        public string StandardError { get; }
        public int ExitCode { get; }

        public ScriptExecutionException(OSPlatform platform, string scriptContent, string standardOutput, 
            string standardError, int exitCode)
            : base(platform, $"Script execution failed on {platform} with exit code {exitCode}")
        {
            ScriptContent = scriptContent;
            StandardOutput = standardOutput;
            StandardError = standardError;
            ExitCode = exitCode;
        }

        public ScriptExecutionException(OSPlatform platform, string scriptContent, string standardOutput, 
            string standardError, int exitCode, Exception innerException)
            : base(platform, $"Script execution failed on {platform} with exit code {exitCode}", innerException)
        {
            ScriptContent = scriptContent;
            StandardOutput = standardOutput;
            StandardError = standardError;
            ExitCode = exitCode;
        }
    }

    /// <summary>
    /// Exception thrown when file operations fail due to platform-specific issues
    /// </summary>
    public class PlatformFileOperationException : PlatformSpecificException
    {
        public string FilePath { get; }
        public string Operation { get; }

        public PlatformFileOperationException(OSPlatform platform, string filePath, string operation, string message)
            : base(platform, $"File operation '{operation}' failed on {platform} for path '{filePath}': {message}")
        {
            FilePath = filePath;
            Operation = operation;
        }

        public PlatformFileOperationException(OSPlatform platform, string filePath, string operation, 
            string message, Exception innerException)
            : base(platform, $"File operation '{operation}' failed on {platform} for path '{filePath}': {message}", innerException)
        {
            FilePath = filePath;
            Operation = operation;
        }
    }

    /// <summary>
    /// Exception thrown when dependency installation or checking fails
    /// </summary>
    public class DependencyException : PlatformSpecificException
    {
        public string DependencyName { get; }
        public string RecommendedAction { get; }

        public DependencyException(OSPlatform platform, string dependencyName, string message, string recommendedAction)
            : base(platform, $"Dependency '{dependencyName}' issue on {platform}: {message}")
        {
            DependencyName = dependencyName;
            RecommendedAction = recommendedAction;
        }

        public DependencyException(OSPlatform platform, string dependencyName, string message, 
            string recommendedAction, Exception innerException)
            : base(platform, $"Dependency '{dependencyName}' issue on {platform}: {message}", innerException)
        {
            DependencyName = dependencyName;
            RecommendedAction = recommendedAction;
        }
    }
}