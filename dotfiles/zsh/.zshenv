# =============================================================================
# ~/.zshenv — Sourced for ALL zsh invocations (interactive, non-interactive,
# scripts). Keep this minimal — only set things that must be available
# everywhere (XDG dirs, basic PATH, etc.)
# =============================================================================

# XDG Base Directory spec
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Ensure local bin is always available
export PATH="$HOME/.local/bin:$PATH"

# mise shims (non-interactive shells need this to find mise-managed tools)
export PATH="$HOME/.local/share/mise/shims:$PATH"
