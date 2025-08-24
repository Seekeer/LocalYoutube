# Design Document

## Overview

This design adds cross-platform support to the download functionality by implementing platform detection and creating Linux-specific download mechanisms. The solution maintains backward compatibility with existing Windows functionality while adding robust Linux support through bash scripts and appropriate executable management.

## Architecture

### Platform Detection Strategy
The system will use `RuntimeInformation.IsOSPlatform()` from `System.Runtime.InteropServices` to detect the operating system at runtime. This approach provides reliable platform detection without external dependencies.

### Download Service Architecture
The current `DownloadService` class will be refactored to support multiple platforms:

```
DownloadService (Abstract Base)
├── WindowsDownloadService (Current Implementation)
└── LinuxDownloadService (New Implementation)
```

A factory pattern will be used to instantiate the appropriate service based on the detected platform.

## Components and Interfaces

### 1. Platform Detection Service
**Interface:** `IPlatformDetectionService`
- `OSPlatform GetCurrentPlatform()`
- `bool IsWindows()`
- `bool IsLinux()`

**Implementation:** `PlatformDetectionService`
- Uses `RuntimeInformation.IsOSPlatform()` for detection
- Provides caching to avoid repeated system calls

### 2. Download Service Factory
**Interface:** `IDownloadServiceFactory`
- `IDownloadService CreateDownloadService(AppConfig config)`

**Implementation:** `DownloadServiceFactory`
- Creates appropriate download service based on platform
- Handles dependency injection for platform-specific services

### 3. Platform-Specific Download Services

#### Windows Download Service
- Maintains existing PowerShell-based implementation
- Uses yt-dlp.exe and ffmpeg.exe
- Executes PowerShell scripts with current logic

#### Linux Download Service
- Implements bash-based download mechanism
- Uses yt-dlp Python package or binary
- Executes bash scripts with equivalent functionality

### 4. Script Management
**Interface:** `IScriptManager`
- `string GetDownloadScript(OSPlatform platform)`
- `string GetUtilitiesScript(OSPlatform platform)`

**Implementation:** `ScriptManager`
- Manages platform-specific scripts
- Handles script template generation
- Provides script validation

## Data Models

### Platform Configuration
```csharp
public class PlatformConfig
{
    public string YtDlpExecutable { get; set; }
    public string FfmpegExecutable { get; set; }
    public string ScriptExtension { get; set; }
    public string ShellExecutable { get; set; }
    public string DownloadScriptTemplate { get; set; }
}
```

### Download Context
```csharp
public class DownloadContext
{
    public OSPlatform Platform { get; set; }
    public string WorkingDirectory { get; set; }
    public string ScriptContent { get; set; }
    public ProcessStartInfo ProcessInfo { get; set; }
}
```

## Error Handling

### Platform-Specific Error Handling
1. **Missing Executables**: Clear error messages indicating required installations
2. **Permission Issues**: Actionable guidance for file system permissions
3. **Script Execution Failures**: Detailed logging with platform context
4. **Network Issues**: Consistent retry logic across platforms

### Error Recovery Strategies
1. **Executable Auto-Download**: Attempt to download missing utilities
2. **Fallback Mechanisms**: Alternative download methods when primary fails
3. **Graceful Degradation**: Reduced functionality when optional components unavailable

## Testing Strategy

### Unit Tests
1. **Platform Detection Tests**
   - Mock different OS environments
   - Verify correct service instantiation
   - Test edge cases and unknown platforms

2. **Download Service Tests**
   - Test both Windows and Linux implementations
   - Mock file system operations
   - Verify script generation and execution

3. **Script Manager Tests**
   - Validate script templates
   - Test parameter substitution
   - Verify platform-specific script generation

### Integration Tests
1. **Cross-Platform Download Tests**
   - Test actual downloads on both platforms
   - Verify file output consistency
   - Test proxy configuration on both platforms

2. **Error Handling Tests**
   - Test missing executable scenarios
   - Verify error message clarity
   - Test recovery mechanisms

### Platform-Specific Testing
1. **Linux Environment Tests**
   - Test on various Linux distributions
   - Verify bash script execution
   - Test Python yt-dlp package usage

2. **Windows Compatibility Tests**
   - Ensure no regression in existing functionality
   - Test PowerShell script execution
   - Verify executable management

## Implementation Details

### Linux Script Template
The Linux implementation will use bash scripts equivalent to the current PowerShell functionality:

```bash
#!/bin/bash
YTDLP="yt-dlp"
FFMPEG="ffmpeg"
ASSETS_DIR="."

# Check and install utilities
if ! command -v $YTDLP &> /dev/null; then
    pip3 install yt-dlp
fi

if ! command -v $FFMPEG &> /dev/null; then
    # Platform-specific ffmpeg installation logic
fi
```

### Process Execution Strategy
- **Windows**: Continue using PowerShell with existing logic
- **Linux**: Use bash with equivalent command structure
- **Cross-Platform**: Unified process management with platform-specific parameters

### File Path Handling
- Maintain consistent path preparation logic
- Handle platform-specific path separators
- Ensure proper file naming across platforms

### Dependency Management
- **Windows**: Continue using existing executable management
- **Linux**: Support both system packages and local binaries
- **Fallback**: Provide clear installation instructions when dependencies missing