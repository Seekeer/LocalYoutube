#!/bin/bash

# Linux download utilities script - equivalent to downloadScript.txt for Windows
# This script ensures all required dependencies are available for video downloads

set -e  # Exit on any error

YTDLP="yt-dlp"
FFMPEG="ffmpeg"
ASSETS="."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to log messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to detect package manager
detect_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists yum; then
        echo "yum"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists zypper; then
        echo "zypper"
    elif command_exists apk; then
        echo "apk"
    else
        echo "unknown"
    fi
}

# Function to install yt-dlp
install_ytdlp() {
    log_message "Installing yt-dlp..."
    
    # Ensure PATH includes user local bin
    export PATH="$HOME/.local/bin:$PATH"
    
    # Try pip3 first
    if command_exists pip3; then
        log_message "Installing yt-dlp via pip3..."
        pip3 install --user yt-dlp --upgrade
    elif command_exists pip; then
        log_message "Installing yt-dlp via pip..."
        pip install --user yt-dlp --upgrade
    elif command_exists python3; then
        log_message "Installing yt-dlp via python3 -m pip..."
        python3 -m pip install --user yt-dlp --upgrade
    else
        log_message "Error: Python/pip not found. Attempting binary download..."
        
        # Try to download binary as fallback
        if command_exists wget; then
            mkdir -p "$HOME/.local/bin"
            wget -q https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O "$HOME/.local/bin/yt-dlp"
            chmod +x "$HOME/.local/bin/yt-dlp"
            log_message "Downloaded yt-dlp binary to ~/.local/bin/yt-dlp"
        elif command_exists curl; then
            mkdir -p "$HOME/.local/bin"
            curl -L -s https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o "$HOME/.local/bin/yt-dlp"
            chmod +x "$HOME/.local/bin/yt-dlp"
            log_message "Downloaded yt-dlp binary to ~/.local/bin/yt-dlp"
        else
            log_message "Error: No suitable installation method found."
            log_message "Please install Python and pip, or download yt-dlp manually from:"
            log_message "https://github.com/yt-dlp/yt-dlp/releases"
            exit 1
        fi
    fi
    
    # Update PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
}

# Function to provide ffmpeg installation instructions
install_ffmpeg() {
    log_message "ffmpeg not found. Providing installation instructions..."
    
    local pm=$(detect_package_manager)
    
    case "$pm" in
        "apt")
            log_message "For Ubuntu/Debian: sudo apt-get update && sudo apt-get install ffmpeg"
            ;;
        "yum")
            log_message "For CentOS/RHEL: sudo yum install epel-release && sudo yum install ffmpeg"
            ;;
        "dnf")
            log_message "For Fedora: sudo dnf install ffmpeg"
            ;;
        "pacman")
            log_message "For Arch Linux: sudo pacman -S ffmpeg"
            ;;
        "zypper")
            log_message "For openSUSE: sudo zypper install ffmpeg"
            ;;
        "apk")
            log_message "For Alpine Linux: sudo apk add ffmpeg"
            ;;
        *)
            log_message "Please install ffmpeg using your system's package manager"
            log_message "Or download from: https://ffmpeg.org/download.html"
            ;;
    esac
}

# Function to verify installation
verify_installation() {
    local success=true
    
    log_message "Verifying installations..."
    
    if command_exists $YTDLP; then
        local version=$(yt-dlp --version 2>/dev/null || echo "unknown")
        log_message "✓ yt-dlp: $version"
    else
        log_message "✗ yt-dlp: Not found"
        success=false
    fi
    
    if command_exists $FFMPEG; then
        local version=$(ffmpeg -version 2>/dev/null | head -n1 | cut -d' ' -f3 || echo "unknown")
        log_message "✓ ffmpeg: $version"
    else
        log_message "⚠ ffmpeg: Not found (optional but recommended)"
    fi
    
    if command_exists python3; then
        local version=$(python3 --version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
        log_message "✓ python3: $version"
    else
        log_message "⚠ python3: Not found"
    fi
    
    return $success
}

# Main execution
log_message "Starting Linux download utilities check..."

# Ensure PATH includes user local bin
export PATH="$HOME/.local/bin:$PATH"

# Check and install yt-dlp
if ! command_exists $YTDLP; then
    install_ytdlp
    
    # Check again after installation
    if ! command_exists $YTDLP; then
        log_message "Error: yt-dlp installation failed or not in PATH"
        log_message "Please check the installation manually or refer to LINUX_DEPLOYMENT.md"
        exit 1
    fi
else
    log_message "yt-dlp is already available"
fi

# Check ffmpeg (warn if not available but don't fail)
if ! command_exists $FFMPEG; then
    log_message "Warning: ffmpeg not found. Some video processing features may not work."
    install_ffmpeg
else
    log_message "ffmpeg is available"
fi

# Verify all installations
if verify_installation; then
    log_message "Utilities check completed successfully"
else
    log_message "Utilities check completed with warnings"
    exit 1
fi