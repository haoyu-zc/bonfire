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

log_success "mise tools installed"
log_info "Run 'mise ls' to see installed tools"
