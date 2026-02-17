#!/usr/bin/env bash
# =============================================================================
# 09-dotfiles.sh — Symlink dotfiles via GNU Stow (both platforms)
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

log_section "Dotfiles"
check_not_root

DOTFILES_DIR="$REPO_DIR/dotfiles"

# =============================================================================
# Ensure GNU Stow is installed
# =============================================================================
if ! command_exists stow; then
    if [[ "$OS" == "linux" ]]; then
        log_info "Installing stow via apt..."
        sudo apt-get install -y stow
    elif [[ "$OS" == "darwin" ]]; then
        setup_homebrew_path
        ensure_brew_formula stow
    fi
fi

if ! command_exists stow; then
    log_error "stow not available after install attempt"
    exit 1
fi

log_success "stow available: $(stow --version | head -1)"

# =============================================================================
# Stow each dotfile package
# =============================================================================
log_info "Stowing dotfile packages from $DOTFILES_DIR..."
cd "$DOTFILES_DIR"

ERRORS=0
for pkg_dir in */; do
    pkg="${pkg_dir%/}"
    [[ -z "$pkg" ]] && continue

    log_step "Stowing: $pkg"

    # --adopt flag would pull real files into the stow dir — don't use it here.
    # Use --restow to re-stow (handles update after package changes).
    if stow -t "$HOME" --restow "$pkg" 2>&1; then
        log_success "Stowed: $pkg"
    else
        log_warn "Conflict stowing '$pkg' — run 'stow -t \$HOME -v --restow $pkg' to debug"
        ((ERRORS++))
    fi
done

if [[ $ERRORS -gt 0 ]]; then
    log_warn "$ERRORS stow conflict(s). Resolve manually or use 'make check' to see drift."
else
    log_success "All dotfile packages stowed successfully"
fi
