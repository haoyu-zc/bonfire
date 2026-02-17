#!/usr/bin/env bash
# =============================================================================
# test-commands.sh — Verify required commands are available
# =============================================================================

# shellcheck source=../scripts/_lib.sh
source "$(dirname "$0")/../scripts/_lib.sh"

log_section "Test: Commands"

PASS=0
FAIL=0

check_cmd() {
    local name="$1"
    local cmd="${2:-$1}"
    if command_exists "$cmd"; then
        log_success "PASS: $name ($(command -v "$cmd"))"
        PASS=$((PASS + 1))
    else
        log_error "FAIL: $name not found"
        FAIL=$((FAIL + 1))
    fi
}

check_version() {
    local name="$1"
    local version_cmd="$2"
    local min_version="$3"
    if version_output="$($version_cmd 2>/dev/null | head -1)"; then
        log_success "PASS: $name ($version_output)"
        PASS=$((PASS + 1))
    else
        log_error "FAIL: $name — cannot get version"
        FAIL=$((FAIL + 1))
    fi
}

# Make mise-managed tools available
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
setup_homebrew_path
command_exists mise && eval "$(mise activate bash 2>/dev/null)" || true

# =============================================================================
# Core system tools
# =============================================================================
log_info "Core system tools..."
check_cmd "zsh"
check_cmd "git"
check_cmd "curl"
check_cmd "wget"
check_cmd "stow"
check_cmd "unzip"

# =============================================================================
# mise
# =============================================================================
log_info "mise..."
check_cmd "mise"

# =============================================================================
# mise-managed CLI tools
# =============================================================================
log_info "mise-managed CLI tools..."
check_cmd "fzf"
check_cmd "zoxide"
check_cmd "rg (ripgrep)" "rg"
check_cmd "bat"
check_cmd "fd"
check_cmd "eza"
check_cmd "delta"
check_cmd "lazygit"
check_cmd "starship"
check_cmd "tldr"
check_cmd "jq"
check_cmd "yq"
check_cmd "uv"
check_cmd "ruff"

# =============================================================================
# Language runtimes
# =============================================================================
log_info "Language runtimes..."
check_cmd "node"
check_version "node version" "node --version" "18"
check_cmd "npm"
check_cmd "python3"
check_version "python version" "python3 --version" "3.12"

# =============================================================================
# Platform-specific tools
# =============================================================================
if [[ "$OS" == "linux" ]]; then
    log_info "Linux-specific tools..."
    check_cmd "podman"
    check_cmd "flatpak"
    check_cmd "apt"

elif [[ "$OS" == "darwin" ]]; then
    log_info "macOS-specific tools..."
    check_cmd "brew"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
log_section "Test Results: Commands"
printf "PASS: %d   FAIL: %d\n" "$PASS" "$FAIL"

[[ $FAIL -eq 0 ]]
