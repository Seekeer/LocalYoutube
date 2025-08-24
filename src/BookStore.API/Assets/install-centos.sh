#!/bin/bash

# CentOS/RHEL Installation Script for BookStore Linux Dependencies
# This script installs all required dependencies for the BookStore application on CentOS/RHEL systems

set -e  # Exit on any error

echo "BookStore Linux Dependencies Installer for CentOS/RHEL"
echo "======================================================"

# Check if running on CentOS/RHEL
if ! command -v yum >/dev/null 2>&1; then
    echo "Error: This script is designed for CentOS/RHEL systems with yum package manager."
    echo "Please use the appropriate installation script for your distribution."
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
is_root() {
    [ "$EUID" -eq 0 ]
}

echo "Checking system requirements..."

# Install EPEL repository (required for ffmpeg)
echo "Installing EPEL repository..."
if is_root; then
    yum install -y epel-release
else
    sudo yum install -y epel-release
fi

# Install core dependencies
echo "Installing core dependencies (Python 3 and pip)..."
if is_root; then
    yum install -y python3 python3-pip
else
    sudo yum install -y python3 python3-pip
fi

# Install optional but recommended dependencies
echo "Installing optional dependencies (ffmpeg, wget)..."
if is_root; then
    yum install -y ffmpeg wget curl
else
    sudo yum install -y ffmpeg wget curl
fi

# Install yt-dlp via pip
echo "Installing yt-dlp via pip..."
pip3 install --user yt-dlp

# Update PATH for current session
export PATH="$HOME/.local/bin:$PATH"

# Add PATH to bashrc if not already present
if ! grep -q "/.local/bin" ~/.bashrc; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo "Added ~/.local/bin to PATH in ~/.bashrc"
fi

# Verify installations
echo ""
echo "Verifying installations..."
echo "========================="

# Check Python
if command_exists python3; then
    echo "✓ Python 3: $(python3 --version)"
else
    echo "✗ Python 3: Not found"
    exit 1
fi

# Check pip
if command_exists pip3; then
    echo "✓ pip3: $(pip3 --version | head -n1)"
else
    echo "✗ pip3: Not found"
    exit 1
fi

# Check yt-dlp
if command_exists yt-dlp; then
    echo "✓ yt-dlp: $(yt-dlp --version)"
else
    echo "✗ yt-dlp: Not found in PATH"
    echo "  Note: You may need to restart your shell or run: source ~/.bashrc"
fi

# Check ffmpeg
if command_exists ffmpeg; then
    echo "✓ ffmpeg: $(ffmpeg -version 2>&1 | head -n1)"
else
    echo "✗ ffmpeg: Not found"
fi

# Check wget
if command_exists wget; then
    echo "✓ wget: $(wget --version | head -n1)"
else
    echo "✗ wget: Not found"
fi

echo ""
echo "Installation completed!"
echo "======================"
echo ""
echo "Next steps:"
echo "1. Restart your shell or run: source ~/.bashrc"
echo "2. Verify yt-dlp is available: yt-dlp --version"
echo "3. Configure your BookStore application"
echo ""
echo "If you encounter any issues, please refer to LINUX_DEPLOYMENT.md for troubleshooting."