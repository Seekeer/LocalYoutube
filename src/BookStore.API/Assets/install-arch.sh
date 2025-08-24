#!/bin/bash

# Arch Linux Installation Script for BookStore Linux Dependencies
# This script installs all required dependencies for the BookStore application on Arch Linux systems

set -e  # Exit on any error

echo "BookStore Linux Dependencies Installer for Arch Linux"
echo "====================================================="

# Check if running on Arch Linux
if ! command -v pacman >/dev/null 2>&1; then
    echo "Error: This script is designed for Arch Linux systems with pacman package manager."
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

# Update package database
echo "Updating package database..."
if is_root; then
    pacman -Sy
else
    sudo pacman -Sy
fi

# Install core dependencies
echo "Installing core dependencies (Python and pip)..."
if is_root; then
    pacman -S --noconfirm python python-pip
else
    sudo pacman -S --noconfirm python python-pip
fi

# Install optional but recommended dependencies
echo "Installing optional dependencies (ffmpeg, wget)..."
if is_root; then
    pacman -S --noconfirm ffmpeg wget curl
else
    sudo pacman -S --noconfirm ffmpeg wget curl
fi

# Install yt-dlp via pip
echo "Installing yt-dlp via pip..."
pip install --user yt-dlp

# Alternative: Check if AUR helper is available and offer AUR installation
if command_exists yay; then
    echo ""
    echo "AUR helper 'yay' detected. You can also install yt-dlp from AUR:"
    echo "  yay -S yt-dlp"
    echo ""
elif command_exists paru; then
    echo ""
    echo "AUR helper 'paru' detected. You can also install yt-dlp from AUR:"
    echo "  paru -S yt-dlp"
    echo ""
fi

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
if command_exists python; then
    echo "✓ Python: $(python --version)"
else
    echo "✗ Python: Not found"
    exit 1
fi

# Check pip
if command_exists pip; then
    echo "✓ pip: $(pip --version | head -n1)"
else
    echo "✗ pip: Not found"
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
echo "Alternative installation methods:"
echo "- AUR package: yay -S yt-dlp (if you have an AUR helper)"
echo ""
echo "If you encounter any issues, please refer to LINUX_DEPLOYMENT.md for troubleshooting."