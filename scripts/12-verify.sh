#!/usr/bin/env bash
# =============================================================================
# 12-verify.sh — Run all checks and print a summary (both platforms)
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

log_section "Verification"

PASS=0
FAIL=0
WARN=0

check_pass() { log_success "PASS: $1"; PASS=$((PASS + 1)); }
check_fail() { log_error  "FAIL: $1"; FAIL=$((FAIL + 1)); }
check_warn() { log_warn   "WARN: $1"; WARN=$((WARN + 1)); }

check_cmd() {
    local name="$1"
    local cmd="${2:-$1}"
    if command_exists "$cmd"; then
        check_pass "$name is available ($(command -v "$cmd"))"
    else
        check_fail "$name not found"
    fi
}

check_file() {
    local label="$1"
    local path="$2"
    if [[ -e "$path" ]]; then
        check_pass "$label exists ($path)"
    else
        check_fail "$label missing ($path)"
    fi
}

check_symlink() {
    local label="$1"
    local path="$2"
    if [[ ! -e "$path" ]] && [[ ! -L "$path" ]]; then
        check_fail "$label missing ($path)"
        return
    fi
    local resolved
    resolved="$(realpath "$path" 2>/dev/null || echo "")"
    # Pass if the resolved path lives inside this repo's dotfiles/
    # (handles both direct symlinks and files under a symlinked parent dir)
    if [[ "$resolved" == "$REPO_DIR/dotfiles/"* ]]; then
        check_pass "$label -> $resolved"
    elif [[ -L "$path" ]]; then
        check_warn "$label symlink points outside repo ($resolved)"
    else
        check_warn "$label exists but is not managed by stow ($path)"
    fi
}

# =============================================================================
# Core commands
# =============================================================================
log_info "Checking core commands..."
check_cmd "zsh"
check_cmd "git"
check_cmd "stow"
check_cmd "curl"
check_cmd "mise"
if [[ "$OS" == "linux" ]]; then
    if command_exists brew; then
        check_pass "brew is available (optional on Linux)"
    else
        check_warn "brew not found (optional on Linux — GUI apps use apt/Flatpak)"
    fi
else
    check_cmd "brew"
fi

# =============================================================================
# mise-managed tools
# =============================================================================
log_info "Checking mise-managed tools..."
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
setup_homebrew_path
if command_exists mise; then
    # Ensure shims are up to date before checking
    mise reshim 2>/dev/null || true
    eval "$(mise activate bash)" 2>/dev/null || true
fi

for tool in node python fzf zoxide rg bat fd eza delta lazygit starship tldr jq yq uv ruff; do
    check_cmd "$tool"
done

# =============================================================================
# Dotfile symlinks
# =============================================================================
log_info "Checking dotfile symlinks..."
check_symlink "~/.zshrc"         "$HOME/.zshrc"
check_symlink "~/.zshenv"        "$HOME/.zshenv"
check_symlink "~/.gitconfig"     "$HOME/.gitconfig"
check_symlink "~/.gitignore_global" "$HOME/.gitignore_global"
check_symlink "starship.toml"    "$HOME/.config/starship.toml"
check_symlink "mise config"      "$HOME/.config/mise/config.toml"
check_symlink "bat config"       "$HOME/.config/bat/config"
check_symlink "lazygit config"   "$HOME/.config/lazygit/config.yml"

# =============================================================================
# Platform-specific checks
# =============================================================================
if [[ "$OS" == "linux" ]]; then
    log_info "Checking Linux-specific items..."

    # Podman
    if command_exists podman; then
        check_pass "podman available"
        if podman info &>/dev/null 2>&1; then
            check_pass "podman info succeeds (rootless)"
        else
            check_warn "podman info failed"
        fi
    else
        check_fail "podman not found"
    fi

    # Flatpak
    if command_exists flatpak; then
        check_pass "flatpak available"
        if flatpak list --app 2>/dev/null | grep -q "md.obsidian.Obsidian"; then
            check_pass "Obsidian (Flatpak) installed"
        else
            check_warn "Obsidian Flatpak not installed"
        fi
    else
        check_warn "flatpak not available"
    fi

    # AppImages
    APPIMAGE_DIR="$HOME/.local/share/AppImages"
    if ls "$APPIMAGE_DIR"/*.AppImage &>/dev/null 2>&1; then
        check_pass "AppImages directory has files ($APPIMAGE_DIR)"
    else
        check_warn "No AppImages found in $APPIMAGE_DIR"
    fi

    # SSH server
    if sudo systemctl is-active ssh &>/dev/null; then
        check_pass "SSH server is running"
        if [[ -f "/etc/ssh/sshd_config.d/99-custom.conf" ]]; then
            check_pass "SSH drop-in config exists"
        else
            check_warn "SSH drop-in config missing"
        fi
    else
        check_warn "SSH server not running"
    fi

    # Key packages
    for pkg in google-chrome-stable code; do
        if apt_installed "$pkg"; then
            check_pass "apt: $pkg installed"
        else
            check_warn "apt: $pkg not installed"
        fi
    done

elif [[ "$OS" == "darwin" ]]; then
    log_info "Checking macOS-specific items..."

    # LaunchAgent for key remapping
    if [[ -f "$HOME/Library/LaunchAgents/com.local.KeyRemapping.plist" ]]; then
        check_pass "Key remapping LaunchAgent installed"
    else
        check_warn "Key remapping LaunchAgent not found"
    fi

    # Check some casks
    for cask in google-chrome visual-studio-code obsidian; do
        if brew_cask_installed "$cask"; then
            check_pass "brew cask: $cask installed"
        else
            check_warn "brew cask: $cask not installed"
        fi
    done
fi

# =============================================================================
# Shell check
# =============================================================================
log_info "Checking default shell..."
CURRENT_SHELL="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || dscl . -read /Users/"$USER" UserShell 2>/dev/null | awk '{print $2}')"
if echo "$CURRENT_SHELL" | grep -q "zsh"; then
    check_pass "Default shell is zsh ($CURRENT_SHELL)"
else
    check_warn "Default shell is $CURRENT_SHELL (not zsh)"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
log_section "Verification Summary"
printf "${C_GREEN}${C_BOLD}  PASS: %d${C_RESET}\n" "$PASS"
printf "${C_YELLOW}${C_BOLD}  WARN: %d${C_RESET}\n" "$WARN"
printf "${C_RED}${C_BOLD}  FAIL: %d${C_RESET}\n" "$FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
    log_error "Some checks failed. Review output above and re-run bootstrap.sh."
    exit 1
elif [[ $WARN -gt 0 ]]; then
    log_warn "Setup complete with warnings. Some optional items may need attention."
else
    log_success "All checks passed! Your machine setup is complete."
fi
