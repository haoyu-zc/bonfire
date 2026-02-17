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
# Back up any real files that would conflict with stow
# =============================================================================
backup_conflicts() {
    local pkg="$1"
    # Dry-run stow and parse conflict lines to find blocking real files.
    # Use || true throughout: stow exits non-zero on conflicts, grep exits
    # non-zero when no matches — both are fine here.
    local conflicts
    conflicts="$(stow -t "$HOME" --restow --simulate "$pkg" 2>&1 || true)"
    conflicts="$(printf '%s\n' "$conflicts" \
        | grep "existing target is neither a link nor a directory" \
        | sed 's/.*: //')" || true

    while IFS= read -r relpath; do
        [[ -z "$relpath" ]] && continue
        local target="$HOME/$relpath"
        if [[ -f "$target" && ! -L "$target" ]]; then
            log_warn "Backing up real file: ~/$relpath -> ~/${relpath}.bak"
            mv "$target" "${target}.bak"
        fi
    done <<< "$conflicts"
}

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

    # Back up any pre-existing real files that would block stow
    backup_conflicts "$pkg"

    if stow -t "$HOME" --restow "$pkg" 2>&1; then
        log_success "Stowed: $pkg"
    else
        log_warn "Conflict stowing '$pkg' — run 'stow -t \$HOME -v --restow $pkg' to debug"
        ERRORS=$((ERRORS + 1))
    fi
done

if [[ $ERRORS -gt 0 ]]; then
    log_warn "$ERRORS stow conflict(s). Resolve manually or use 'make check' to see drift."
else
    log_success "All dotfile packages stowed successfully"
fi
