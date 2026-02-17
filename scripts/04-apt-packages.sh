#!/usr/bin/env bash
# =============================================================================
# 04-apt-packages.sh — Install apt packages (Linux only)
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

[[ "$OS" == "linux" ]] || { log_info "Skipping apt packages (not Linux)"; exit 0; }

log_section "APT Packages"
check_not_root

PACKAGES_TOML="$REPO_DIR/config/packages.toml"

log_info "Installing apt packages from packages.toml..."

# Batch install for efficiency: collect all packages first
packages=()
while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if apt_installed "$pkg"; then
        log_success "apt: $pkg (already installed)"
    else
        packages+=("$pkg")
    fi
done < <(toml_get_array "$PACKAGES_TOML" "packages")

if [[ ${#packages[@]} -eq 0 ]]; then
    log_success "All apt packages already installed"
else
    log_info "Installing ${#packages[@]} package(s): ${packages[*]}"
    sudo apt-get install -y "${packages[@]}"
    log_success "Installed ${#packages[@]} package(s)"
fi

# Add current user to docker group (avoid needing sudo for docker)
if apt_installed docker-ce || command_exists docker; then
    if ! groups "$USER" | grep -q docker; then
        log_info "Adding $USER to docker group..."
        sudo usermod -aG docker "$USER"
        log_warn "Log out and back in for docker group membership to take effect"
    else
        log_success "User already in docker group"
    fi
fi

log_success "APT packages installation complete"
