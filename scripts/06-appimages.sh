#!/usr/bin/env bash
# =============================================================================
# 06-appimages.sh — Download and install AppImages (Linux only)
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

[[ "$OS" == "linux" ]] || { log_info "Skipping AppImages (not Linux)"; exit 0; }

log_section "AppImages"
check_not_root

APPIMAGES_TOML="$REPO_DIR/config/appimages.toml"

APPIMAGE_DIR="$HOME/.local/share/AppImages"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"

mkdir -p "$APPIMAGE_DIR" "$DESKTOP_DIR" "$ICON_DIR"

# =============================================================================
# Install a single AppImage
# install_appimage <toml_key> <url> <name> <icon_url> <categories>
# =============================================================================
install_appimage() {
    local key="$1"
    local url="$2"
    local name="$3"
    local icon_url="$4"
    local categories="$5"

    local filename
    filename="$(basename "$url")"
    local appimage_path="$APPIMAGE_DIR/$filename"
    local desktop_file="$DESKTOP_DIR/${key}.desktop"
    local icon_path="$ICON_DIR/${key}.svg"

    # Download AppImage if not present
    if [[ -f "$appimage_path" ]]; then
        log_success "AppImage: $name (already downloaded)"
    else
        log_step "Downloading $name from $url"
        curl -fsSL --progress-bar -o "$appimage_path" "$url"
        chmod +x "$appimage_path"
        log_success "AppImage: $name downloaded to $appimage_path"
    fi

    # Download icon if not present
    if [[ -n "$icon_url" ]] && [[ ! -f "$icon_path" ]]; then
        log_step "Downloading icon for $name"
        curl -fsSL -o "$icon_path" "$icon_url" 2>/dev/null || true
    fi

    # Create .desktop file if not present
    if [[ -f "$desktop_file" ]]; then
        log_success "AppImage: $name desktop entry (already exists)"
    else
        log_step "Creating desktop entry for $name"
        local icon_ref
        if [[ -f "$icon_path" ]]; then
            icon_ref="$icon_path"
        else
            icon_ref="$key"
        fi

        cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=$name
Exec=$appimage_path --no-sandbox
Icon=$icon_ref
Type=Application
Categories=$categories
StartupNotify=true
EOF
        # Register with desktop database
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
        log_success "AppImage: $name desktop entry created"
    fi
}

# =============================================================================
# Process all AppImages from appimages.toml
# =============================================================================
log_info "Processing AppImage definitions from appimages.toml..."

# Get all top-level section keys (e.g., "snipaste")
while IFS= read -r key; do
    [[ -z "$key" ]] && continue

    url="$(toml_get_table_value "$APPIMAGES_TOML" "$key" "url")"
    name="$(toml_get_table_value "$APPIMAGES_TOML" "$key" "name")"
    icon_url="$(toml_get_table_value "$APPIMAGES_TOML" "$key" "icon_url")"
    categories="$(toml_get_table_value "$APPIMAGES_TOML" "$key" "categories")"

    if [[ -z "$url" ]]; then
        log_warn "Skipping AppImage '$key': missing url"
        continue
    fi

    install_appimage "$key" "$url" "${name:-$key}" "${icon_url:-}" "${categories:-Utility;}"
done < <(awk '/^\[[a-z]/ { gsub(/[\[\]]/, ""); if ($0 !~ /\./) print $0 }' "$APPIMAGES_TOML")

log_success "AppImages setup complete"
