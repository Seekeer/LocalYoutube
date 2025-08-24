# BookStore Assets Directory

This directory contains platform-specific assets and scripts for the BookStore application.

## Windows Assets
- `downloadScript.txt` - PowerShell script for Windows dependency management and downloads
- `yt-dlp.exe` - Windows executable for video downloads
- `ffmpeg.exe` - Windows executable for video processing
- `ffprobe.exe` - Windows executable for media information
- `phantomjs.exe` - Windows executable for web automation
- `bat.zip` - Additional Windows utilities

## Linux Assets
- `downloadScript.sh` - Bash script equivalent to downloadScript.txt for Linux systems
- `LINUX_DEPLOYMENT.md` - Comprehensive Linux deployment documentation
- `install-ubuntu.sh` - Ubuntu/Debian installation script
- `install-centos.sh` - CentOS/RHEL installation script  
- `install-fedora.sh` - Fedora installation script
- `install-arch.sh` - Arch Linux installation script

## Usage

### Windows
The Windows assets are used automatically by the WindowsDownloadService. No manual setup required.

### Linux
1. Review `LINUX_DEPLOYMENT.md` for complete deployment instructions
2. Use the appropriate installation script for your distribution:
   ```bash
   # Make scripts executable (on Linux)
   chmod +x *.sh
   
   # Run the appropriate installer
   ./install-ubuntu.sh    # For Ubuntu/Debian
   ./install-centos.sh    # For CentOS/RHEL
   ./install-fedora.sh    # For Fedora
   ./install-arch.sh      # For Arch Linux
   ```
3. The `downloadScript.sh` is used automatically by the LinuxDownloadService

## Platform Detection
The application automatically detects the operating system and uses the appropriate assets:
- Windows: Uses .exe files and PowerShell scripts
- Linux: Uses bash scripts and system package managers

## Dependencies
### Linux Dependencies
- Python 3.6+
- pip3
- yt-dlp (installed via pip or package manager)
- ffmpeg (optional but recommended)

### Windows Dependencies
- PowerShell (built into Windows)
- Executables are included in this directory

## Troubleshooting
- For Linux issues, refer to `LINUX_DEPLOYMENT.md`
- For Windows issues, ensure PowerShell execution policy allows script execution
- Check application logs for detailed error messages and dependency status