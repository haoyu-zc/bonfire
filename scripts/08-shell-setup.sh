#!/usr/bin/env bash
# =============================================================================
# 08-shell-setup.sh — Ensure Zsh is installed and set as default shell
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

log_section "Shell Setup"
check_not_root

# =============================================================================
# Install Zsh (+ the plugins .zshrc sources)
# --admin installs them outright. A per-user run on Linux offers to install
# them when the user can sudo (sudo/admin/wheel group), since without root
# there's no clean way to get zsh. Under --yes that only happens when sudo
# works without a password; otherwise the step is skipped with a hint.
# =============================================================================
ZSH_APT_PKGS=(zsh zsh-autosuggestions zsh-syntax-highlighting)

can_sudo() {
    sudo -n true 2>/dev/null || id -Gn | tr ' ' '\n' | grep -qxE 'sudo|admin|wheel'
}

if [[ "$OS" == "linux" ]]; then
    MISSING_PKGS=()
    for pkg in "${ZSH_APT_PKGS[@]}"; do
        apt_installed "$pkg" || MISSING_PKGS+=("$pkg")
    done

    if [[ ${#MISSING_PKGS[@]} -eq 0 ]]; then
        log_success "zsh + plugins already installed: $(zsh --version)"
    else
        install_ok=0
        if is_admin; then
            install_ok=1
        elif can_sudo; then
            if [[ "${AUTO_YES:-0}" -eq 1 ]]; then
                sudo -n true 2>/dev/null && install_ok=1
            else
                printf -- '%bNot installed: %s. Install with sudo apt now? [Y/n] %b' \
                    "$C_YELLOW" "${MISSING_PKGS[*]}" "$C_RESET"
                if ! read -r answer; then answer="n"; fi
                [[ "$answer" != "n" && "$answer" != "N" ]] && install_ok=1
            fi
        fi

        if [[ $install_ok -eq 1 ]]; then
            log_info "Installing ${MISSING_PKGS[*]} via apt..."
            run sudo apt-get install -y "${MISSING_PKGS[@]}"
            log_success "Installed ${MISSING_PKGS[*]}"
        elif ! command_exists zsh; then
            log_warn "zsh is not installed. Install it with:"
            log_warn "    sudo apt-get install -y ${ZSH_APT_PKGS[*]}"
            log_warn "(or ask the admin to run 'bootstrap.sh --admin'), then: bash bootstrap.sh --only shell"
            log_success "Shell setup skipped (no zsh)"
            exit 0
        fi
    fi
elif [[ "$OS" == "darwin" ]]; then
    # Zsh ships with macOS; install newer version via brew if desired
    if command_exists zsh; then
        log_success "zsh already installed: $(zsh --version)"
    elif command_exists brew; then
        ensure_brew_formula zsh
    fi
fi

if [[ "${DRY_RUN:-0}" -eq 1 ]] && ! command_exists zsh; then
    log_info "Would set zsh as the default shell"
    exit 0
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
    # Ensure zsh is in /etc/shells (admin-only write; chsh needs it listed)
    if ! grep -qF "$ZSH_PATH" /etc/shells; then
        if is_admin; then
            log_info "Adding $ZSH_PATH to /etc/shells..."
            echo "$ZSH_PATH" | sudo tee -a /etc/shells
        else
            log_warn "$ZSH_PATH not in /etc/shells (admin adds it) — chsh may fail."
        fi
    fi

    log_info "Setting default shell to zsh for $USER..."
    if chsh -s "$ZSH_PATH" "$USER"; then
        log_success "Default shell changed to zsh — restart your session to take effect"
    else
        log_warn "Could not change default shell — run manually: chsh -s $ZSH_PATH"
    fi
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
