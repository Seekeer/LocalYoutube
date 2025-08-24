# Linux Deployment Requirements

This document outlines the requirements and setup instructions for deploying the BookStore application on Linux systems with download functionality.

## System Requirements

### Supported Linux Distributions
- Ubuntu 18.04 LTS or later
- Debian 9 or later
- CentOS 7 or later
- RHEL 7 or later
- Fedora 30 or later
- Arch Linux (current)
- openSUSE Leap 15.0 or later
- Alpine Linux 3.10 or later

### Required Dependencies

#### Core Dependencies (Required)
1. **Python 3.6+** - Required for yt-dlp installation and execution
2. **pip3** - Python package manager for installing yt-dlp
3. **yt-dlp** - Video download utility (replaces youtube-dl)

#### Optional Dependencies (Recommended)
1. **ffmpeg** - Video processing and format conversion
2. **wget** or **curl** - For downloading binaries if needed

## Installation Instructions

### Ubuntu/Debian Systems

```bash
# Update package list
sudo apt-get update

# Install core dependencies
sudo apt-get install python3 python3-pip

# Install optional dependencies
sudo apt-get install ffmpeg wget

# Install yt-dlp via pip
pip3 install --user yt-dlp

# Add user local bin to PATH (add to ~/.bashrc for persistence)
export PATH="$HOME/.local/bin:$PATH"
```

### CentOS/RHEL Systems

```bash
# Install EPEL repository (required for ffmpeg)
sudo yum install epel-release

# Install core dependencies
sudo yum install python3 python3-pip

# Install optional dependencies
sudo yum install ffmpeg wget

# Install yt-dlp via pip
pip3 install --user yt-dlp

# Add user local bin to PATH (add to ~/.bashrc for persistence)
export PATH="$HOME/.local/bin:$PATH"
```

### Fedora Systems

```bash
# Install core dependencies
sudo dnf install python3 python3-pip

# Install optional dependencies
sudo dnf install ffmpeg wget

# Install yt-dlp via pip
pip3 install --user yt-dlp

# Add user local bin to PATH (add to ~/.bashrc for persistence)
export PATH="$HOME/.local/bin:$PATH"
```

### Arch Linux Systems

```bash
# Install core dependencies
sudo pacman -S python python-pip

# Install optional dependencies
sudo pacman -S ffmpeg wget

# Install yt-dlp via pip
pip install --user yt-dlp

# Alternative: Install from AUR
yay -S yt-dlp

# Add user local bin to PATH (add to ~/.bashrc for persistence)
export PATH="$HOME/.local/bin:$PATH"
```

### openSUSE Systems

```bash
# Install core dependencies
sudo zypper install python3 python3-pip

# Install optional dependencies
sudo zypper install ffmpeg wget

# Install yt-dlp via pip
pip3 install --user yt-dlp

# Add user local bin to PATH (add to ~/.bashrc for persistence)
export PATH="$HOME/.local/bin:$PATH"
```

### Alpine Linux Systems

```bash
# Install core dependencies
sudo apk add python3 py3-pip

# Install optional dependencies
sudo apk add ffmpeg wget

# Install yt-dlp via pip
pip3 install --user yt-dlp

# Add user local bin to PATH (add to ~/.bashrc for persistence)
export PATH="$HOME/.local/bin:$PATH"
```

## Alternative Installation Methods

### Binary Installation (No Python Required)

If you prefer not to use Python/pip, you can download the yt-dlp binary directly:

```bash
# Create local bin directory if it doesn't exist
mkdir -p ~/.local/bin

# Download yt-dlp binary
wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O ~/.local/bin/yt-dlp

# Make it executable
chmod +x ~/.local/bin/yt-dlp

# Add to PATH (add to ~/.bashrc for persistence)
export PATH="$HOME/.local/bin:$PATH"
```

### Docker Deployment

For containerized deployments, use the following Dockerfile additions:

```dockerfile
# Add to your existing Dockerfile
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    ffmpeg \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --user yt-dlp

# Ensure PATH includes user local bin
ENV PATH="/root/.local/bin:${PATH}"
```

## Verification

After installation, verify that all dependencies are available:

```bash
# Check Python
python3 --version

# Check pip
pip3 --version

# Check yt-dlp
yt-dlp --version

# Check ffmpeg (optional but recommended)
ffmpeg -version

# Test download functionality (optional)
yt-dlp --help
```

## Troubleshooting

### Common Issues

#### 1. yt-dlp not found after installation
**Problem**: Command not found error when running yt-dlp
**Solution**: Ensure ~/.local/bin is in your PATH
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 2. Permission denied errors
**Problem**: Permission errors when installing packages
**Solution**: Use --user flag with pip or run with appropriate permissions
```bash
pip3 install --user yt-dlp  # Install for current user only
```

#### 3. ffmpeg not available
**Problem**: Video processing fails due to missing ffmpeg
**Solution**: Install ffmpeg using your system's package manager
```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg

# CentOS/RHEL
sudo yum install epel-release && sudo yum install ffmpeg

# Fedora
sudo dnf install ffmpeg
```

#### 4. Python version too old
**Problem**: yt-dlp requires Python 3.6+
**Solution**: Update Python or use alternative installation methods
```bash
# Check Python version
python3 --version

# If version is too old, consider using binary installation method
```

#### 5. Network connectivity issues
**Problem**: Downloads fail due to network restrictions
**Solution**: Configure proxy settings in the application configuration
- The application supports HTTP/HTTPS proxy configuration
- Proxy settings are automatically passed to yt-dlp

### Log Files and Debugging

The application logs detailed information about dependency checks and download operations:

1. **Dependency Status**: Check logs for dependency availability messages
2. **Installation Attempts**: Monitor logs for automatic installation results
3. **Download Errors**: Review error messages for specific failure reasons
4. **Platform Detection**: Verify correct platform and package manager detection

### Performance Considerations

#### System Resources
- **CPU**: Video processing (if using ffmpeg) can be CPU-intensive
- **Memory**: Large video downloads may require significant RAM
- **Disk Space**: Ensure adequate space for temporary and final video files
- **Network**: Download speed depends on available bandwidth

#### Optimization Tips
1. **Concurrent Downloads**: Limit concurrent downloads to avoid system overload
2. **Temporary Files**: Regularly clean up temporary download files
3. **Format Selection**: Choose appropriate video formats to balance quality and file size
4. **Proxy Configuration**: Use local proxy servers to improve download speeds

## Security Considerations

### File Permissions
- Ensure download directories have appropriate permissions
- Avoid running the application as root unless necessary
- Use dedicated user accounts for production deployments

### Network Security
- Configure firewall rules for outbound connections
- Use HTTPS proxies when possible
- Monitor download sources for security compliance

### Updates and Maintenance
- Regularly update yt-dlp to the latest version
- Keep system packages updated for security patches
- Monitor for deprecated dependencies

## Production Deployment Checklist

- [ ] All required dependencies installed and verified
- [ ] PATH environment variable configured correctly
- [ ] ffmpeg available for video processing
- [ ] Adequate disk space for downloads
- [ ] Network connectivity and proxy configuration tested
- [ ] Log monitoring and error handling configured
- [ ] Security permissions and user accounts configured
- [ ] Backup and recovery procedures established
- [ ] Performance monitoring and resource limits configured
- [ ] Update procedures and maintenance schedules defined

## Support and Resources

### Official Documentation
- [yt-dlp GitHub Repository](https://github.com/yt-dlp/yt-dlp)
- [ffmpeg Documentation](https://ffmpeg.org/documentation.html)
- [Python Installation Guide](https://www.python.org/downloads/)

### Community Resources
- [yt-dlp Issues and Support](https://github.com/yt-dlp/yt-dlp/issues)
- [Linux Distribution Documentation](https://distrowatch.com/)

### Application-Specific Support
- Check application logs for detailed error messages
- Review dependency manager output for installation issues
- Consult platform-specific error handling documentation