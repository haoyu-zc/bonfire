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

# =============================================================================
# Preflight: require a GitHub token before installing tools
# Every ubi:/github: tool resolves its version tag via the GitHub /releases API.
# Unauthenticated requests are capped at 60/hr and fail mid-install with a 403;
# a token (no scopes required) raises this to 5000/hr. mise reads GITHUB_TOKEN.
#
# We accept a token from the environment or from an already-authenticated gh.
# If neither is present we STOP the whole bootstrap (exit EXIT_ACTION_REQUIRED)
# with instructions, rather than burning the rate limit or driving gh's
# interactive prompt (unreliable over SSH/Ghostty — it misreads terminal escape
# sequences). NOTE: scripts run under `set -euo pipefail` (_lib.sh), so the gh
# token is read inside the `if` condition to stay set-e-safe.
# =============================================================================
if [[ -z "${GITHUB_TOKEN:-}" && -z "${GITHUB_API_TOKEN:-}" && -z "${MISE_GITHUB_TOKEN:-}" ]]; then
    # No system gh (per-user run without --admin): use mise's, as suggested below.
    if command_exists gh; then GH=(gh); else GH=(mise exec gh@latest -- gh); fi
    if GITHUB_TOKEN="$("${GH[@]}" auth token 2>/dev/null)" && [[ -n "$GITHUB_TOKEN" ]]; then
        export GITHUB_TOKEN
        log_info "Using GitHub token from gh CLI (avoids API rate limits)"
    elif [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        log_warn "[dry-run] no GitHub token — a real run would stop here until gh is authenticated."
    else
        log_error "mise needs a GitHub token, but none is available."
        log_error "mise looks up every tool's version via the GitHub API; unauthenticated"
        log_error "requests are capped at 60/hr and fail mid-install (HTTP 403)."
        log_error ""
        log_error "Fix it once. Run this directly at your shell prompt (it's interactive,"
        log_error "and works best outside the bootstrap):"
        log_error ""
        if command_exists gh; then
            log_error "    gh auth login"
        else
            # Don't suggest `mise use -g gh`: it writes ~/.config/mise/config.toml,
            # which then conflicts with the stowed one in 09-dotfiles.
            log_error "    mise exec gh@latest -- gh auth login"
        fi
        log_error ""
        log_error "  - choose 'Login with a web browser'"
        log_error "  - gh prints a one-time code, e.g.  ABCD-1234"
        log_error "  - on your laptop, open  https://github.com/login/device  and enter it"
        log_error "  - this box has no browser, so 'Failed opening a web browser' is normal —"
        log_error "    just open that URL on your laptop and type the code there"
        log_error ""
        log_error "  Prefer a token? Create a no-scope one at https://github.com/settings/tokens:"
        log_error "    gh auth login --with-token <<<'ghp_xxx'   (or: export GITHUB_TOKEN=ghp_xxx)"
        log_error ""
        log_error "Once 'gh auth status' shows you logged in, resume:"
        log_error "    bash bootstrap.sh --from 07-mise.sh"
        exit "$EXIT_ACTION_REQUIRED"
    fi
fi

log_info "Installing all tools from mise config (this may take a while)..."
run mise install --yes

log_info "Regenerating mise shims..."
run mise reshim

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
    # Release assets are per-arch; a mismatched binary fails with "Exec format error".
    case "$(uname -m)" in
        x86_64 | amd64) TLDR_ASSET="tealdeer-linux-x86_64-musl" ;;
        aarch64 | arm64) TLDR_ASSET="tealdeer-linux-aarch64-musl" ;;
        armv7l) TLDR_ASSET="tealdeer-linux-armv7-musleabihf" ;;
        *) TLDR_ASSET="" ;;
    esac
    LATEST_TLDR="https://github.com/tealdeer-rs/tealdeer/releases/latest/download/$TLDR_ASSET"

    if command_exists tldr && tldr --version 2>/dev/null | grep -qv "1\.6\."; then
        log_success "tealdeer already installed: $(tldr --version)"
    elif [[ -z "$TLDR_ASSET" ]]; then
        log_warn "No tealdeer binary for arch $(uname -m) — skipping"
    else
        log_info "Installing tealdeer (latest $TLDR_ASSET from GitHub releases)..."
        mkdir -p "$(dirname "$TLDR_BIN")"
        run curl -fsSL "$LATEST_TLDR" -o "$TLDR_BIN"
        run chmod +x "$TLDR_BIN"
        if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
            if ! "$TLDR_BIN" --version >/dev/null 2>&1; then
                log_error "Downloaded tealdeer binary does not run on this machine ($(uname -m))"
                exit 1
            fi
            log_success "tealdeer installed: $("$TLDR_BIN" --version)"

            log_info "Updating tldr cache..."
            "$TLDR_BIN" --update && log_success "tldr cache updated" || log_warn "tldr cache update failed — run 'tldr --update' manually"
        fi
    fi
fi
