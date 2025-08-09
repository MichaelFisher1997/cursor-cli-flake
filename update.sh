#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to get latest version from cursor.com install script
get_latest_version() {
    log "Fetching latest version from cursor.com/install..."
    
    # Download the install script and extract the version
    local install_script
    install_script=$(curl -s https://cursor.com/install)
    
    # Extract version from the URL pattern in the script
    # Look for patterns like "2025.08.08-f57cb59" in download URLs
    local version
    version=$(echo "$install_script" | grep -oP 'downloads\.cursor\.com/lab/\K[^/]+' | head -1)
    
    if [[ -z "$version" ]]; then
        error "Could not extract version from install script"
        exit 1
    fi
    
    echo "$version"
}

# Function to build URLs for a given version
build_urls() {
    local version="$1"
    local base_url="https://downloads.cursor.com/lab/${version}/linux"
    
    echo "${base_url}/x64/agent-cli-package.tar.gz"
    echo "${base_url}/arm64/agent-cli-package.tar.gz"
}

# Function to prefetch hash for a URL
prefetch_hash() {
    local url="$1"
    local arch="$2"
    
    log "Prefetching hash for $arch: $url"
    
    local hash
    if ! hash=$(nix store prefetch-file "$url" --hash-type sha256 2>/dev/null | grep -o 'sha256-[A-Za-z0-9+/=]*'); then
        error "Failed to prefetch hash for $arch"
        return 1
    fi
    
    echo "$hash"
}

# Function to update flake.nix with new version and hashes
update_flake() {
    local version="$1"
    local x64_hash="$2"
    local arm64_hash="$3"
    
    log "Updating flake.nix with version $version..."
    
    # Create a backup
    cp flake.nix flake.nix.backup
    
    # Update version
    sed -i "s|version = \"[^\"]*\"|version = \"$version\"|" flake.nix
    
    # Update x64 URL and hash
    sed -i "/x86_64-linux = {/,/};/ {
        s|url = \"[^\"]*\"|url = \"https://downloads.cursor.com/lab/$version/linux/x64/agent-cli-package.tar.gz\"|
        s|hash = \"[^\"]*\"|hash = \"$x64_hash\"|
    }" flake.nix
    
    # Update arm64 URL and hash  
    sed -i "/aarch64-linux = {/,/};/ {
        s|url = \"[^\"]*\"|url = \"https://downloads.cursor.com/lab/$version/linux/arm64/agent-cli-package.tar.gz\"|
        s|hash = \"[^\"]*\"|hash = \"$arm64_hash\"|
    }" flake.nix
    
    success "Updated flake.nix"
}

# Main function
main() {
    local target_version="$1"
    
    # Check if we're in the right directory
    if [[ ! -f "flake.nix" ]]; then
        error "flake.nix not found. Run this script from the repository root."
        exit 1
    fi
    
    # Check if nix is available
    if ! command -v nix &> /dev/null; then
        error "nix command not found. Please install Nix."
        exit 1
    fi
    
    # Get version (use provided or fetch latest)
    local version
    if [[ -n "$target_version" ]]; then
        version="$target_version"
        log "Using specified version: $version"
    else
        version=$(get_latest_version)
        log "Latest version detected: $version"
    fi
    
    # Build URLs
    local urls
    IFS=$'\n' read -d '' -r -a urls < <(build_urls "$version")
    local x64_url="${urls[0]}"
    local arm64_url="${urls[1]}"
    
    log "x64 URL: $x64_url"
    log "arm64 URL: $arm64_url"
    
    # Prefetch hashes
    local x64_hash arm64_hash
    
    log "Prefetching hashes (this may take a moment)..."
    
    if ! x64_hash=$(prefetch_hash "$x64_url" "x64"); then
        error "Failed to get x64 hash"
        exit 1
    fi
    
    if ! arm64_hash=$(prefetch_hash "$arm64_url" "arm64"); then
        error "Failed to get arm64 hash"  
        exit 1
    fi
    
    success "x64 hash: $x64_hash"
    success "arm64 hash: $arm64_hash"
    
    # Update flake.nix
    update_flake "$version" "$x64_hash" "$arm64_hash"
    
    # Verify the flake builds
    log "Testing flake build..."
    if nix build .#cursor-cli --no-link; then
        success "Flake builds successfully!"
    else
        error "Flake build failed. Restoring backup..."
        mv flake.nix.backup flake.nix
        exit 1
    fi
    
    # Clean up backup
    rm -f flake.nix.backup
    
    success "Update completed successfully!"
    log "Version: $version"
    log "You can now commit the changes and push to your repository."
}

# Script usage
usage() {
    echo "Usage: $0 [VERSION]"
    echo ""
    echo "Update Cursor CLI flake to latest or specified version."
    echo ""
    echo "Arguments:"
    echo "  VERSION    Specific version to update to (optional)"
    echo "             If not provided, will fetch latest version"
    echo ""
    echo "Examples:"
    echo "  $0                    # Update to latest version"
    echo "  $0 2025.08.15-abc123  # Update to specific version"
}

# Parse arguments
if [[ $# -gt 1 ]]; then
    error "Too many arguments"
    usage
    exit 1
elif [[ $# -eq 1 && ("$1" == "-h" || "$1" == "--help") ]]; then
    usage
    exit 0
fi

# Run main function
main "${1:-}"