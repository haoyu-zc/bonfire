#!/usr/bin/env bash
# =============================================================================
# 02-homebrew.sh — Install Homebrew and packages
# Formulae: installed on both Linux and macOS
# Casks: macOS only
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

log_section "Homebrew Setup"
check_not_root

PACKAGES_TOML="$REPO_DIR/config/packages.toml"

# =============================================================================
# Install Homebrew
# =============================================================================
if command_exists brew; then
    log_success "Homebrew already installed: $(brew --version | head -1)"
else
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    log_success "Homebrew installed"
fi

# Activate brew in current shell
setup_homebrew_path

# Verify brew is now available
if ! command_exists brew; then
    log_error "brew not found after installation — check PATH"
    exit 1
fi

# Update Homebrew
log_info "Updating Homebrew..."
brew update

# =============================================================================
# Install formulae (both platforms)
# =============================================================================
log_info "Installing Homebrew formulae..."
while IFS= read -r formula; do
    [[ -z "$formula" ]] && continue
    ensure_brew_formula "$formula"
done < <(toml_get_array "$PACKAGES_TOML" "formulae")

# =============================================================================
# Install casks (macOS only)
# =============================================================================
if [[ "$OS" == "darwin" ]]; then
    log_info "Installing Homebrew casks (macOS)..."
    while IFS= read -r cask; do
        [[ -z "$cask" ]] && continue
        ensure_brew_cask "$cask"
    done < <(toml_get_array "$PACKAGES_TOML" "casks")
else
    log_info "Skipping casks (Linux — GUI apps installed via apt/Flatpak/AppImage)"
fi

# Run cleanup
log_info "Running brew cleanup..."
brew cleanup

log_success "Homebrew setup complete"
