#!/usr/bin/env bash
# =============================================================================
# 03-apt-repos.sh — Add third-party apt repositories (Linux only)
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

[[ "$OS" == "linux" ]] || { log_info "Skipping apt repos setup (not Linux)"; exit 0; }

log_section "APT Repositories"
check_not_root

PACKAGES_TOML="$REPO_DIR/config/packages.toml"

# Ensure required tools are available
for tool in curl gpg; do
    if ! command_exists "$tool"; then
        sudo apt-get install -y "$tool"
    fi
done

sudo install -m 0755 -d /etc/apt/keyrings

# =============================================================================
# Add a single apt repo
# add_apt_repo <name> <key_url> <repo_line>
# =============================================================================
add_apt_repo() {
    local name="$1"
    local key_url="$2"
    local repo_line="$3"
    local keyring_path="/etc/apt/keyrings/${name}.gpg"
    local sources_path="/etc/apt/sources.list.d/${name}.list"

    if [[ -f "$sources_path" ]]; then
        log_success "repo: $name (already configured)"
        return 0
    fi

    log_step "Adding repo: $name"

    # Download and dearmor the GPG key
    log_step "  Importing GPG key from $key_url"
    curl -fsSL "$key_url" | sudo gpg --dearmor -o "$keyring_path"
    sudo chmod a+r "$keyring_path"

    # Write the repo source line, referencing the keyring
    # Inject signed-by= into the repo line's options bracket if present
    if echo "$repo_line" | grep -q '\['; then
        # Already has bracket options — inject signed-by=
        local modified_line
        modified_line="$(echo "$repo_line" | sed "s|\[|\[signed-by=$keyring_path |")"
        echo "$modified_line" | sudo tee "$sources_path" > /dev/null
    else
        echo "$repo_line" | sudo tee "$sources_path" > /dev/null
    fi

    log_success "repo: $name added"
}

# =============================================================================
# Process all repos from packages.toml
# =============================================================================
log_info "Processing repo definitions from packages.toml..."

while IFS= read -r repo_name; do
    [[ -z "$repo_name" ]] && continue
    section="apt.repos.${repo_name}"
    key_url="$(toml_get_table_value "$PACKAGES_TOML" "$section" "key")"
    repo_line="$(toml_get_table_value "$PACKAGES_TOML" "$section" "repo")"

    if [[ -z "$key_url" || -z "$repo_line" ]]; then
        log_warn "Skipping repo '$repo_name': missing key or repo value"
        continue
    fi

    add_apt_repo "$repo_name" "$key_url" "$repo_line"
done < <(toml_get_section_keys "$PACKAGES_TOML" "apt.repos")

# Update package lists with new repos
log_info "Updating apt package lists with new repos..."
sudo apt-get update -qq

log_success "APT repositories configured"
