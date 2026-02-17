#!/usr/bin/env bash
# =============================================================================
# 05-flatpak.sh — Install Flatpak apps (Linux only)
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

[[ "$OS" == "linux" ]] || { log_info "Skipping flatpak (not Linux)"; exit 0; }

log_section "Flatpak Apps"
check_not_root

PACKAGES_TOML="$REPO_DIR/config/packages.toml"

# =============================================================================
# Ensure Flatpak is installed
# =============================================================================
if ! command_exists flatpak; then
    log_info "Installing flatpak..."
    sudo apt-get install -y flatpak
    log_success "flatpak installed"
else
    log_success "flatpak already installed"
fi

# Add Flathub remote if not already present
if ! flatpak remote-list 2>/dev/null | grep -q "flathub"; then
    log_info "Adding Flathub remote..."
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    log_success "Flathub remote added"
else
    log_success "Flathub remote already configured"
fi

# =============================================================================
# Install Flatpak packages
# =============================================================================
log_info "Installing Flatpak apps from packages.toml..."
while IFS= read -r app_id; do
    [[ -z "$app_id" ]] && continue
    ensure_flatpak "$app_id"
done < <(toml_get_array "$PACKAGES_TOML" "packages")

log_success "Flatpak setup complete"
