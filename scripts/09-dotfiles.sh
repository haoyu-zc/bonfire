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
# Capture any pre-existing git identity BEFORE stowing.
# If a user previously ran `git config --global user.name …`, that write landed
# in ~/.gitconfig — which (post-stow) is a symlink into this repo. Once we
# re-stow the new identity-less .gitconfig, that value is gone. Read it now so
# we can migrate it into ~/.gitconfig.local further down.
# =============================================================================
GIT_PRESEED_NAME=""
GIT_PRESEED_EMAIL=""
if command_exists git; then
    GIT_PRESEED_NAME="$(git config --global user.name 2>/dev/null || true)"
    GIT_PRESEED_EMAIL="$(git config --global user.email 2>/dev/null || true)"
fi

# =============================================================================
# Ensure GNU Stow is installed
# =============================================================================
# A per-user stow (built below) lives in ~/.local/bin, which may not be on PATH yet.
export PATH="$HOME/.local/bin:$PATH"

if ! command_exists stow; then
    if is_admin; then
        if [[ "$OS" == "linux" ]]; then
            log_info "Installing stow via apt..."
            run sudo apt-get install -y stow
        elif [[ "$OS" == "darwin" ]]; then
            setup_homebrew_path
            ensure_brew_formula stow
        fi
    elif command_exists perl && command_exists make; then
        # No sudo in a per-user run: build GNU Stow (a perl script) into
        # ~/.local from the upstream tarball. Only perl + make are needed.
        log_info "Installing stow into ~/.local (per-user, from GNU source)..."
        STOW_BUILD="$(mktemp -d)"
        trap 'rm -rf "$STOW_BUILD"' EXIT
        run curl -fsSL https://ftp.gnu.org/gnu/stow/stow-latest.tar.gz -o "$STOW_BUILD/stow.tar.gz"
        run tar -xzf "$STOW_BUILD/stow.tar.gz" -C "$STOW_BUILD" --strip-components=1
        # configure warns about missing test-only perl modules (Test::Output);
        # the install itself doesn't need them. Build output is only shown if
        # the build fails — it's noise otherwise.
        if ! run bash -c 'cd "$1" && { ./configure --prefix="$HOME/.local" && make install; } >build.log 2>&1' \
            _ "$STOW_BUILD"; then
            cat "$STOW_BUILD/build.log"
            log_error "Building stow failed (output above)"
            exit 1
        fi
    else
        log_error "stow is required but not installed, and perl/make are missing to build it."
        log_error "Ask the admin to run 'bash bootstrap.sh --admin' (installs stow system-wide),"
        log_error "then resume: bash bootstrap.sh --from 09-dotfiles"
        exit "$EXIT_ACTION_REQUIRED"
    fi
fi

if [[ "${DRY_RUN:-0}" -eq 1 ]] && ! command_exists stow; then
    log_info "Would install stow — skipping the rest of the dotfiles step in dry-run"
    exit 0
fi

if ! command_exists stow; then
    log_error "stow not available after install attempt"
    exit 1
fi

log_success "stow available: $(stow --version | head -1)"

# =============================================================================
# Real files that would block stowing a package (one ~-relative path per line)
# =============================================================================
stow_conflicts() {
    local pkg="$1" relpath
    # stow exits non-zero on conflicts; that's the case we're parsing. The
    # message differs by version: 2.3 ("existing target is neither a link nor
    # a directory: PATH") vs 2.4 ("over existing target PATH since neither …").
    stow -t "$HOME" --restow --simulate "$pkg" 2>&1 \
        | sed -nE 's/.*existing target is neither a link nor a directory: (.*)$/\1/p
                  s/.*over existing target (.*) since neither a link nor a directory.*/\1/p' \
        | while IFS= read -r relpath; do
            [[ -f "$HOME/$relpath" && ! -L "$HOME/$relpath" ]] && printf '%s\n' "$relpath"
        done || true
}

# Back up any real files that would conflict with stow
backup_conflicts() {
    local pkg="$1" relpath
    while IFS= read -r relpath; do
        [[ -z "$relpath" ]] && continue
        log_warn "Backing up real file: ~/$relpath -> ~/${relpath}.bak"
        run mv "$HOME/$relpath" "$HOME/${relpath}.bak"
    done < <(stow_conflicts "$pkg")
}

# =============================================================================
# Pre-flight: only real files that stow would replace need a decision. Missing
# links are what stowing creates, so they don't warrant a prompt (run
# `make check` for the full drift report).
# =============================================================================
cd "$DOTFILES_DIR" || exit 1

CONFLICTS=()
for pkg_dir in */; do
    pkg="${pkg_dir%/}"
    while IFS= read -r relpath; do
        [[ -n "$relpath" ]] && CONFLICTS+=("$relpath")
    done < <(stow_conflicts "$pkg")
done

if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
    log_warn "These existing files will be moved to *.bak and replaced by repo symlinks:"
    for relpath in "${CONFLICTS[@]}"; do
        log_warn "    ~/$relpath"
    done
    if [[ "${AUTO_YES:-0}" -eq 0 ]]; then
        printf -- '%bBack them up and continue? [y/N] %b' "$C_YELLOW" "$C_RESET"
        # `read` returns non-zero on closed stdin (e.g., script piped from
        # a non-tty); guard so set -e doesn't abort before we can default.
        if ! read -r answer; then answer=""; fi
        if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
            log_error "Left your files untouched. Move or merge them yourself, then resume:"
            log_error "    bash bootstrap.sh --from 09-dotfiles"
            exit "$EXIT_ACTION_REQUIRED"
        fi
    fi
fi

# =============================================================================
# Stow each dotfile package
# =============================================================================
log_info "Stowing dotfile packages from $DOTFILES_DIR..."

ERRORS=0
for pkg_dir in */; do
    pkg="${pkg_dir%/}"
    [[ -z "$pkg" ]] && continue

    log_step "Stowing: $pkg"

    # Back up any pre-existing real files that would block stow
    backup_conflicts "$pkg"

    if run stow -t "$HOME" --restow "$pkg" 2>&1; then
        if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
            log_info "Would stow: $pkg"
        else
            log_success "Stowed: $pkg"
        fi
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

# =============================================================================
# Per-user git identity
# The stowed ~/.gitconfig holds no name/email (it's shared across users) and
# instead includes ~/.gitconfig.local. Create that local, untracked file here
# so each user gets their own identity instead of inheriting the repo owner's.
# =============================================================================
GIT_LOCAL="$HOME/.gitconfig.local"
# Consider identity "already set" only when BOTH name and email are present —
# a half-populated local file should fall through and get completed.
existing_name=""
existing_email=""
if command_exists git && [[ -f "$GIT_LOCAL" ]]; then
    existing_name="$(git config --file "$GIT_LOCAL" user.name 2>/dev/null || true)"
    existing_email="$(git config --file "$GIT_LOCAL" user.email 2>/dev/null || true)"
fi

if ! command_exists git; then
    log_warn "git not installed yet — skipping ~/.gitconfig.local setup (re-run after git is available)"
elif [[ -n "$existing_name" && -n "$existing_email" ]]; then
    log_success "git identity already set in ~/.gitconfig.local ($existing_name <$existing_email>)"
elif [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "Would create ~/.gitconfig.local with your git identity"
else
    # Seed coherently from ONE source so we never pair a name from the local
    # file with an email from a stale global (or vice versa): if the local
    # file already has either field, treat it as authoritative and let the
    # prompt fill the gap; otherwise fall back to the pre-stow global identity.
    if [[ -n "$existing_name" || -n "$existing_email" ]]; then
        git_name="$existing_name"
        git_email="$existing_email"
    else
        git_name="$GIT_PRESEED_NAME"
        git_email="$GIT_PRESEED_EMAIL"
    fi

    if [[ "${AUTO_YES:-0}" -eq 0 ]]; then
        printf -- '%bGit user name%b [%s]: ' "$C_CYAN" "$C_RESET" "${git_name:-Your Name}"
        if ! read -r answer; then answer=""; fi
        [[ -n "$answer" ]] && git_name="$answer"
        printf -- '%bGit email%b [%s]: ' "$C_CYAN" "$C_RESET" "${git_email:-you@example.com}"
        if ! read -r answer; then answer=""; fi
        [[ -n "$answer" ]] && git_email="$answer"
    fi

    cat >"$GIT_LOCAL" <<EOF
# Local, untracked git identity. Edit freely — this file lives only in your
# home directory and is never part of the bonfire repo or stow. Update with:
#   git config --file ~/.gitconfig.local user.name  "Your Name"
#   git config --file ~/.gitconfig.local user.email "you@example.com"
[user]
	name = ${git_name:-Your Name}
	email = ${git_email:-you@example.com}
EOF

    if [[ -z "$git_name" || -z "$git_email" ]]; then
        log_warn "Wrote ~/.gitconfig.local with placeholders — edit it before committing"
    else
        log_success "Wrote git identity to ~/.gitconfig.local ($git_name <$git_email>)"
    fi
fi
