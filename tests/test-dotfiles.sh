#!/usr/bin/env bash
# =============================================================================
# test-dotfiles.sh — Verify dotfile symlinks are correct
# =============================================================================

# shellcheck source=../scripts/_lib.sh
source "$(dirname "$0")/../scripts/_lib.sh"

log_section "Test: Dotfiles"

PASS=0
FAIL=0
WARN=0

check_symlink() {
    local label="$1"
    local path="$2"
    local expected_target="$3"

    if [[ ! -e "$path" ]] && [[ ! -L "$path" ]]; then
        log_error "FAIL: $label — missing ($path)"
        ((FAIL++))
    elif [[ -L "$path" ]]; then
        actual_target="$(readlink -f "$path")"
        if [[ -n "$expected_target" ]] && [[ "$actual_target" != "$expected_target" ]]; then
            log_error "FAIL: $label — wrong target"
            log_error "       got:      $actual_target"
            log_error "       expected: $expected_target"
            ((FAIL++))
        else
            log_success "PASS: $label -> $actual_target"
            ((PASS++))
        fi
    else
        log_warn "WARN: $label — exists but is NOT a symlink (may conflict with stow)"
        ((WARN++))
    fi
}

DOTFILES_DIR="$REPO_DIR/dotfiles"

# =============================================================================
# Check each file managed by stow
# =============================================================================
log_info "Checking stow-managed dotfiles..."
cd "$DOTFILES_DIR"

for pkg_dir in */; do
    pkg="${pkg_dir%/}"
    [[ -z "$pkg" ]] && continue
    log_info "Package: $pkg"

    while IFS= read -r -d '' file; do
        relpath="${file#./}"
        relpath="${relpath#$pkg/}"
        expected="$DOTFILES_DIR/$pkg/$relpath"
        target="$HOME/$relpath"
        check_symlink "~/$relpath" "$target" "$expected"
    done < <(find "$pkg" -type f -print0)
done

# =============================================================================
# Check that stow packages exist in dotfiles/
# =============================================================================
log_info "Checking expected stow packages exist..."
EXPECTED_PKGS=(zsh git starship mise bat lazygit)
for pkg in "${EXPECTED_PKGS[@]}"; do
    if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
        log_success "PASS: package '$pkg' exists"
        ((PASS++))
    else
        log_error "FAIL: package '$pkg' missing from dotfiles/"
        ((FAIL++))
    fi
done

# =============================================================================
# Summary
# =============================================================================
echo ""
log_section "Test Results: Dotfiles"
printf "PASS: %d   WARN: %d   FAIL: %d\n" "$PASS" "$WARN" "$FAIL"

[[ $FAIL -eq 0 ]]
