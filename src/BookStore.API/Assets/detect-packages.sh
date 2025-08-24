#!/bin/bash

# Linux Package Detection Script for BookStore
# This script detects available package managers and required dependencies

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
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

# Function to check dependency status
check_dependency() {
    local dep="$1"
    if command_exists "$dep"; then
        echo "available"
    else
        echo "missing"
    fi
}

# Function to get version of a dependency
get_version() {
    local dep="$1"
    case "$dep" in
        "python3")
            if command_exists python3; then
                python3 --version 2>&1 | cut -d' ' -f2
            else
                echo "not_found"
            fi
            ;;
        "pip3")
            if command_exists pip3; then
                pip3 --version 2>&1 | cut -d' ' -f2
            else
                echo "not_found"
            fi
            ;;
        "yt-dlp")
            if command_exists yt-dlp; then
                yt-dlp --version 2>&1
            else
                echo "not_found"
            fi
            ;;
        "ffmpeg")
            if command_exists ffmpeg; then
                ffmpeg -version 2>&1 | head -n1 | cut -d' ' -f3
            else
                echo "not_found"
            fi
            ;;
        *)
            echo "unknown_dependency"
            ;;
    esac
}

# Function to get distribution information
get_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Function to get distribution version
get_distribution_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

# Main execution based on command line arguments
case "${1:-status}" in
    "package-manager")
        detect_package_manager
        ;;
    "distribution")
        get_distribution
        ;;
    "distribution-version")
        get_distribution_version
        ;;
    "check")
        if [ -n "$2" ]; then
            check_dependency "$2"
        else
            echo "Usage: $0 check <dependency_name>"
            exit 1
        fi
        ;;
    "version")
        if [ -n "$2" ]; then
            get_version "$2"
        else
            echo "Usage: $0 version <dependency_name>"
            exit 1
        fi
        ;;
    "status"|*)
        echo "=== Linux Package Detection Report ==="
        echo "Distribution: $(get_distribution)"
        echo "Distribution Version: $(get_distribution_version)"
        echo "Package Manager: $(detect_package_manager)"
        echo ""
        echo "=== Dependency Status ==="
        
        dependencies=("python3" "pip3" "yt-dlp" "ffmpeg" "wget" "curl")
        
        for dep in "${dependencies[@]}"; do
            status=$(check_dependency "$dep")
            version=$(get_version "$dep")
            printf "%-10s: %-10s" "$dep" "$status"
            if [ "$status" = "available" ] && [ "$version" != "not_found" ]; then
                printf " (version: %s)" "$version"
            fi
            echo ""
        done
        
        echo ""
        echo "=== Installation Commands ==="
        pm=$(detect_package_manager)
        case "$pm" in
            "apt")
                echo "Install missing packages:"
                echo "  sudo apt-get update"
                echo "  sudo apt-get install python3 python3-pip ffmpeg wget curl"
                echo "  pip3 install --user yt-dlp"
                ;;
            "yum")
                echo "Install missing packages:"
                echo "  sudo yum install epel-release"
                echo "  sudo yum install python3 python3-pip ffmpeg wget curl"
                echo "  pip3 install --user yt-dlp"
                ;;
            "dnf")
                echo "Install missing packages:"
                echo "  sudo dnf install python3 python3-pip ffmpeg wget curl"
                echo "  pip3 install --user yt-dlp"
                ;;
            "pacman")
                echo "Install missing packages:"
                echo "  sudo pacman -S python python-pip ffmpeg wget curl"
                echo "  pip install --user yt-dlp"
                ;;
            "zypper")
                echo "Install missing packages:"
                echo "  sudo zypper install python3 python3-pip ffmpeg wget curl"
                echo "  pip3 install --user yt-dlp"
                ;;
            "apk")
                echo "Install missing packages:"
                echo "  sudo apk add python3 py3-pip ffmpeg wget curl"
                echo "  pip3 install --user yt-dlp"
                ;;
            *)
                echo "Unknown package manager. Please install manually:"
                echo "  - Python 3.6+"
                echo "  - pip3"
                echo "  - ffmpeg (optional)"
                echo "  - yt-dlp (via pip: pip3 install --user yt-dlp)"
                ;;
        esac
        ;;
esac