#!/usr/bin/env bash
# =============================================================================
# 08-shell-setup.sh — Ensure Zsh is installed and set as default shell
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

log_section "Shell Setup"
check_not_root

# =============================================================================
# Install Zsh
# =============================================================================
if command_exists zsh; then
    log_success "zsh already installed: $(zsh --version)"
else
    if [[ "$OS" == "linux" ]]; then
        log_info "Installing zsh via apt..."
        sudo apt-get install -y zsh
        log_success "zsh installed"
    elif [[ "$OS" == "darwin" ]]; then
        # Zsh ships with macOS; install newer version via brew if desired
        log_info "Zsh should be pre-installed on macOS"
        if command_exists brew; then
            ensure_brew_formula zsh
        fi
    fi
fi

ZSH_PATH="$(command -v zsh)"
export ZSH_PATH

# =============================================================================
# Set Zsh as default shell
# =============================================================================
CURRENT_SHELL="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || dscl . -read /Users/"$USER" UserShell 2>/dev/null | awk '{print $2}')"

if [[ "$CURRENT_SHELL" == "$ZSH_PATH" ]]; then
    log_success "zsh is already the default shell"
else
    # Ensure zsh is in /etc/shells
    if ! grep -qF "$ZSH_PATH" /etc/shells; then
        log_info "Adding $ZSH_PATH to /etc/shells..."
        echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi

    log_info "Setting default shell to zsh for $USER..."
    chsh -s "$ZSH_PATH" "$USER"
    log_success "Default shell changed to zsh — restart your session to take effect"
fi

# =============================================================================
# Ensure zsh plugin paths are available for .zshrc
# =============================================================================
if [[ "$OS" == "linux" ]]; then
    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        if [[ -d "/usr/share/${plugin}" ]]; then
            log_success "zsh plugin: $plugin (found at /usr/share/${plugin})"
        else
            log_warn "zsh plugin: $plugin not found — install with apt or brew"
        fi
    done
fi

log_success "Shell setup complete"
