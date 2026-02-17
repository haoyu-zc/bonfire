#!/usr/bin/env bash
# =============================================================================
# 07-mise.sh — Install mise and dev tools/runtimes (both platforms)
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

log_section "mise Dev Tools"
check_not_root

MISE_CONFIG="$REPO_DIR/dotfiles/mise/.config/mise/config.toml"

# =============================================================================
# Install mise
# =============================================================================
if command_exists mise; then
    log_success "mise already installed: $(mise --version)"
else
    log_info "Installing mise..."
    curl -fsSL https://mise.run | sh
    log_success "mise installed"
fi

# Make mise available in current shell
export PATH="$HOME/.local/bin:$PATH"

if ! command_exists mise; then
    log_error "mise not found after install — check ~/.local/bin is in PATH"
    exit 1
fi

# =============================================================================
# Trust and install tools from global config
# =============================================================================
log_info "Trusting mise config at $MISE_CONFIG..."
mise trust "$MISE_CONFIG" 2>/dev/null || true

# Set the global config path so mise picks it up
export MISE_GLOBAL_CONFIG_FILE="$MISE_CONFIG"

log_info "Installing all tools from mise config (this may take a while)..."
mise install --yes

log_info "Regenerating mise shims..."
mise reshim

log_success "mise tools installed"
log_info "Run 'mise ls' to see installed tools"

# =============================================================================
# Install tealdeer (tldr) — Linux only
# The apt-packaged version (1.6.1) has a hardcoded broken cache URL.
# Download the latest binary directly from GitHub releases instead.
# On macOS, tealdeer is installed via brew (see packages.toml).
# =============================================================================
if [[ "$OS" == "linux" ]]; then
    TLDR_BIN="$HOME/.local/bin/tldr"
    LATEST_TLDR="https://github.com/dbrgn/tealdeer/releases/latest/download/tealdeer-linux-x86_64-musl"

    if command_exists tldr && tldr --version 2>/dev/null | grep -qv "1\.6\."; then
        log_success "tealdeer already installed: $(tldr --version)"
    else
        log_info "Installing tealdeer (latest binary from GitHub releases)..."
        curl -fsSL "$LATEST_TLDR" -o "$TLDR_BIN"
        chmod +x "$TLDR_BIN"
        log_success "tealdeer installed: $("$TLDR_BIN" --version)"

        log_info "Updating tldr cache..."
        "$TLDR_BIN" --update 2>/dev/null && log_success "tldr cache updated" || log_warn "tldr cache update failed — run 'tldr --update' manually"
    fi
fi
