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

check_pass() { log_success "PASS: $1"; ((PASS++)); }
check_fail() { log_error  "FAIL: $1"; ((FAIL++)); }
check_warn() { log_warn   "WARN: $1"; ((WARN++)); }

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
    if [[ -L "$path" ]]; then
        local target
        target="$(readlink -f "$path")"
        check_pass "$label is symlink -> $target"
    elif [[ -e "$path" ]]; then
        check_warn "$label exists but is NOT a symlink ($path)"
    else
        check_fail "$label missing ($path)"
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
check_cmd "brew"

# =============================================================================
# mise-managed tools
# =============================================================================
log_info "Checking mise-managed tools..."
export PATH="$HOME/.local/bin:$PATH"
setup_homebrew_path
if command_exists mise; then
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
check_symlink "starship.toml"    "$HOME/.config/starship/starship.toml"
check_symlink "mise config"      "$HOME/.config/mise/config.toml"
check_symlink "bat config"       "$HOME/.config/bat/config"
check_symlink "lazygit config"   "$HOME/.config/lazygit/config.yml"

# =============================================================================
# Platform-specific checks
# =============================================================================
if [[ "$OS" == "linux" ]]; then
    log_info "Checking Linux-specific items..."

    # Docker
    if command_exists docker; then
        check_pass "docker available"
        if sudo docker info &>/dev/null 2>&1; then
            check_pass "docker daemon running"
        else
            check_warn "docker daemon not running (or needs sudo)"
        fi
        if groups "$USER" | grep -q docker; then
            check_pass "user in docker group"
        else
            check_warn "user NOT in docker group (run 'sudo usermod -aG docker $USER')"
        fi
    else
        check_fail "docker not found"
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
