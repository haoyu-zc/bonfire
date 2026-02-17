#!/usr/bin/env bash
# =============================================================================
# 11-desktop-settings.sh — Desktop/keyboard settings (platform-specific)
# Linux: COSMIC desktop preferences (CapsLock/Escape swap via xkb_config)
# macOS: defaults + hidutil + LaunchAgent for key remapping
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

log_section "Desktop Settings"
check_not_root

# =============================================================================
# LINUX — COSMIC desktop
# =============================================================================
if [[ "$OS" == "linux" ]]; then
    COSMIC_COMP_DIR="$HOME/.config/cosmic/com.system76.CosmicComp/v1"
    XKB_CONFIG_FILE="$COSMIC_COMP_DIR/xkb_config"

    # Note: COSMIC overwrites symlinks in its config directory — we write directly
    mkdir -p "$COSMIC_COMP_DIR"

    log_info "Configuring COSMIC xkb: CapsLock ↔ Escape swap..."

    if [[ -f "$XKB_CONFIG_FILE" ]]; then
        # File exists — check if our option is already there
        if grep -q "caps:swapescape" "$XKB_CONFIG_FILE"; then
            log_success "COSMIC xkb: caps:swapescape already configured"
        else
            # Append to existing options string — this handles various formats
            # The COSMIC xkb_config is a RON (Rusty Object Notation) file
            # Look for "options: Some(" pattern and add our option
            if grep -q '"options"' "$XKB_CONFIG_FILE"; then
                # Options string already exists, append our option
                sed -i 's/"options": Some("\([^"]*\)")/options: Some("\1,caps:swapescape")/' "$XKB_CONFIG_FILE" || true
                log_success "COSMIC xkb: added caps:swapescape to existing options"
            else
                log_warn "COSMIC xkb_config format unrecognized — writing fresh config"
                write_cosmic_xkb=1
            fi
        fi
    else
        write_cosmic_xkb=1
    fi

    if [[ "${write_cosmic_xkb:-0}" == "1" ]]; then
        # Write a fresh minimal xkb config with our swap
        # COSMIC uses RON format for its config files
        cat > "$XKB_CONFIG_FILE" <<'EOF'
(
    rules: None,
    model: None,
    layout: None,
    variant: None,
    options: Some("caps:swapescape"),
)
EOF
        log_success "COSMIC xkb config written with caps:swapescape"
    fi

    log_warn "Log out and back in (or restart COSMIC) for the xkb change to take effect"

    # ==========================================================================
    # Additional COSMIC settings (add more here as needed)
    # ==========================================================================

    # Set natural scrolling, etc. via gsettings if available
    if command_exists gsettings; then
        # Example: set clock format
        gsettings set org.gnome.desktop.interface clock-format '24h' 2>/dev/null || true
    fi

fi

# =============================================================================
# macOS
# =============================================================================
if [[ "$OS" == "darwin" ]]; then

    # --------------------------------------------------------------------------
    # CapsLock → Escape via hidutil + persistent LaunchAgent
    # --------------------------------------------------------------------------
    LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
    LAUNCH_AGENT_PLIST="$LAUNCH_AGENT_DIR/com.local.KeyRemapping.plist"

    mkdir -p "$LAUNCH_AGENT_DIR"

    log_info "Configuring CapsLock ↔ Escape swap via hidutil..."

    # Apply immediately
    hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029},{"HIDKeyboardModifierMappingSrc":0x700000029,"HIDKeyboardModifierMappingDst":0x700000039}]}' 2>/dev/null || true

    if [[ -f "$LAUNCH_AGENT_PLIST" ]]; then
        log_success "LaunchAgent for key remapping already exists"
    else
        log_info "Creating persistent LaunchAgent for key remapping..."
        cat > "$LAUNCH_AGENT_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local.KeyRemapping</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/hidutil</string>
        <string>property</string>
        <string>--set</string>
        <string>{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029},{"HIDKeyboardModifierMappingSrc":0x700000029,"HIDKeyboardModifierMappingDst":0x700000039}]}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
        # Load it now
        launchctl load "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
        log_success "LaunchAgent for key remapping created and loaded"
    fi

    # --------------------------------------------------------------------------
    # macOS system defaults
    # --------------------------------------------------------------------------
    log_info "Applying macOS system defaults..."

    # Finder: show extensions, path bar, status bar
    defaults write com.apple.finder AppleShowAllExtensions -bool true
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder ShowStatusBar -bool true
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"  # list view

    # Dock: auto-hide, smaller size
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock tilesize -int 48
    defaults write com.apple.dock minimize-to-application -bool true

    # Trackpad: tap to click
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

    # Keyboard: fast key repeat
    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 15

    # Screenshots: save to ~/Pictures/Screenshots
    mkdir -p "$HOME/Pictures/Screenshots"
    defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
    defaults write com.apple.screencapture type -string "png"
    defaults write com.apple.screencapture disable-shadow -bool true

    # Menu bar: show clock in 24h, show battery percentage
    defaults write com.apple.menuextra.clock DateFormat -string "EEE HH:mm"
    defaults write com.apple.menuextra.battery ShowPercent -bool true

    # Disable Gatekeeper quarantine for downloaded apps (use with care)
    # defaults write com.apple.LaunchServices LSQuarantine -bool false

    # Restart affected apps
    for app in Finder Dock SystemUIServer; do
        killall "$app" 2>/dev/null || true
    done

    log_success "macOS defaults applied"
fi

log_success "Desktop settings complete"
