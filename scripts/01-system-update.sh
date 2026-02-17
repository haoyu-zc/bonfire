#!/usr/bin/env bash
# =============================================================================
# 01-system-update.sh — Update system packages
# Runs on both Linux and macOS.
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

log_section "System Update"
check_not_root

if [[ "$OS" == "linux" ]]; then
    log_info "Updating apt package lists..."
    sudo apt-get update -qq

    log_info "Upgrading installed packages..."
    sudo apt-get upgrade -y

    log_info "Installing basic prerequisites..."
    sudo apt-get install -y curl wget git ca-certificates gnupg software-properties-common

    log_success "System update complete"

elif [[ "$OS" == "darwin" ]]; then
    # Ensure Xcode Command Line Tools are installed
    if ! xcode-select -p &>/dev/null; then
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        # Wait for installation to complete
        until xcode-select -p &>/dev/null; do
            sleep 5
        done
        log_success "Xcode Command Line Tools installed"
    else
        log_success "Xcode Command Line Tools already installed"
    fi

    # Accept Xcode license if needed
    if ! sudo xcodebuild -license status 2>/dev/null | grep -q "accepted"; then
        log_info "Accepting Xcode license..."
        sudo xcodebuild -license accept
    fi

    # Run softwareupdate for macOS system updates (non-interactive)
    log_info "Checking for macOS software updates..."
    softwareupdate --list 2>&1 | grep -i "recommended" || true
    log_warn "Run 'softwareupdate --install --all' manually to install macOS updates"
fi
