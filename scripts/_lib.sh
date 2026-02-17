#!/usr/bin/env bash
# =============================================================================
# _lib.sh — Shared utilities for machine-setup scripts
# Sourced by all numbered scripts; never run directly.
# =============================================================================

set -euo pipefail

# =============================================================================
# OS / Distro Detection
# =============================================================================
detect_os() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        OS="darwin"
        DISTRO="macos"
    elif [[ "$(uname -s)" == "Linux" ]]; then
        OS="linux"
        if [[ -f /etc/os-release ]]; then
            # shellcheck source=/dev/null
            source /etc/os-release
            case "${ID:-}" in
                pop)    DISTRO="pop" ;;
                ubuntu) DISTRO="ubuntu" ;;
                *)      DISTRO="${ID:-unknown}" ;;
            esac
        else
            DISTRO="unknown"
        fi
    else
        OS="unknown"
        DISTRO="unknown"
    fi
    export OS DISTRO
}

detect_os

# =============================================================================
# Paths
# =============================================================================
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_DIR

LOG_FILE="$REPO_DIR/setup.log"
export LOG_FILE

# =============================================================================
# Color Logging
# =============================================================================
# Colors (only when stdout is a terminal)
if [[ -t 1 ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_BLUE='\033[34m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_RED='\033[31m'
    C_CYAN='\033[36m'
else
    C_RESET='' C_BOLD='' C_BLUE='' C_GREEN='' C_YELLOW='' C_RED='' C_CYAN=''
fi

_log() {
    local level="$1" color="$2" prefix="$3"
    shift 3
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    # Print to stdout with color
    printf "${color}${C_BOLD}${prefix}${C_RESET}${color} %s${C_RESET}\n" "$msg"
    # Append plain text to log file
    printf '[%s] [%s] %s\n' "$timestamp" "$level" "$msg" >> "$LOG_FILE"
}

log_info()    { _log "INFO"    "$C_BLUE"   "==>" "$@"; }
log_success() { _log "OK"      "$C_GREEN"  "  ✓" "$@"; }
log_warn()    { _log "WARN"    "$C_YELLOW" "  !" "$@"; }
log_error()   { _log "ERROR"   "$C_RED"    "  ✗" "$@"; }
log_step()    { _log "STEP"    "$C_CYAN"   "---" "$@"; }

# Print a section header
log_section() {
    local title="$1"
    local line="============================================================"
    printf "\n${C_BOLD}${C_BLUE}%s${C_RESET}\n" "$line"
    printf "${C_BOLD}${C_BLUE}  %s${C_RESET}\n" "$title"
    printf "${C_BOLD}${C_BLUE}%s${C_RESET}\n\n" "$line"
    printf '\n[SECTION] %s\n' "$title" >> "$LOG_FILE"
}

# =============================================================================
# Safety checks
# =============================================================================
check_not_root() {
    if [[ "$EUID" -eq 0 ]]; then
        log_error "Do not run as root. The script uses sudo internally where needed."
        exit 1
    fi
}

# =============================================================================
# Idempotency helpers
# =============================================================================
command_exists() { command -v "$1" &>/dev/null; }

apt_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

flatpak_installed() {
    flatpak list --app --columns=application 2>/dev/null | grep -q "^${1}$"
}

brew_installed() {
    brew list --formula 2>/dev/null | grep -q "^${1}$"
}

brew_cask_installed() {
    brew list --cask 2>/dev/null | grep -q "^${1}$"
}

# =============================================================================
# Ensure helpers (idempotent install wrappers)
# =============================================================================
ensure_apt_package() {
    local pkg="$1"
    if apt_installed "$pkg"; then
        log_success "apt: $pkg (already installed)"
    else
        log_step "apt: installing $pkg"
        sudo apt-get install -y "$pkg"
        log_success "apt: $pkg installed"
    fi
}

ensure_flatpak() {
    local app_id="$1"
    if flatpak_installed "$app_id"; then
        log_success "flatpak: $app_id (already installed)"
    else
        log_step "flatpak: installing $app_id"
        flatpak install -y flathub "$app_id"
        log_success "flatpak: $app_id installed"
    fi
}

ensure_brew_formula() {
    local pkg="$1"
    if brew_installed "$pkg"; then
        log_success "brew: $pkg (already installed)"
    else
        log_step "brew: installing formula $pkg"
        brew install "$pkg"
        log_success "brew: $pkg installed"
    fi
}

ensure_brew_cask() {
    local pkg="$1"
    if brew_cask_installed "$pkg"; then
        log_success "brew cask: $pkg (already installed)"
    else
        log_step "brew cask: installing $pkg"
        brew install --cask "$pkg"
        log_success "brew cask: $pkg installed"
    fi
}

# =============================================================================
# TOML Parsing (lightweight, handles the subset used in this repo)
# =============================================================================

# toml_get_array <file> <section> <key>
# Extracts items from a TOML array under [section] key = ["a", "b", ...].
# Section-aware and strips comment lines before parsing.
toml_get_array() {
    local file="$1"
    local section="$2"
    local key="$3"
    awk -v section="$section" -v key="$key" '
    BEGIN { in_section=0; collecting=0; buffer="" }
    /^\[/ {
        header=$0
        gsub(/^\[|\]$/, "", header)
        in_section = (header == section) ? 1 : 0
        # If we were mid-collection and hit a new section, abort
        if (!in_section) { collecting=0; buffer="" }
        next
    }
    in_section {
        # Skip comment lines entirely (avoids commas inside comments)
        if ($0 ~ /^[[:space:]]*#/) next

        line=$0
        if (!collecting && line ~ "^[[:space:]]*" key "[[:space:]]*=") {
            collecting=1
            sub(/^[^=]+=/, "", line)       # drop everything up to =
            sub(/^[^[]*\[/, "", line)      # drop up to opening [
            buffer=line
        } else if (collecting) {
            buffer=buffer " " line
        }

        if (collecting && buffer ~ /\]/) {
            sub(/\].*$/, "", buffer)       # drop closing ] and beyond
            collecting=0
            n=split(buffer, items, ",")
            for (i=1; i<=n; i++) {
                item=items[i]
                gsub(/^[[:space:]"]+|[[:space:]"]+$/, "", item)
                if (item != "") print item
            }
            buffer=""
        }
    }
    ' "$file"
}

# toml_get_value <file> <section> <key>
# Returns a single string value from [section] key = "value"
toml_get_value() {
    local file="$1"
    local section="$2"
    local key="$3"
    awk -v section="$section" -v key="$key" '
    BEGIN { in_section=0 }
    /^\[/ {
        # Check if this is our section
        if ($0 == "[" section "]") {
            in_section=1
        } else {
            in_section=0
        }
        next
    }
    in_section && $1 == key && $2 == "=" {
        val=$3
        # Remove surrounding quotes
        gsub(/^["'"'"']|["'"'"']$/, "", val)
        print val
        exit
    }
    ' "$file"
}

# toml_get_section_keys <file> <parent_section>
# Returns top-level keys under a dotted parent, e.g. "apt.repos" -> "google-chrome", "vscode", ...
toml_get_section_keys() {
    local file="$1"
    local parent="$2"
    awk -v parent="$parent" '
    /^\[/ {
        # Match [parent.KEY] or [parent.KEY.subkey]
        header=$0
        gsub(/^\[|\]$/, "", header)
        if (header ~ "^" parent "\\.") {
            # Extract the immediate child key
            sub("^" parent "\\.", "", header)
            # Get just first segment
            n=split(header, parts, ".")
            if (n == 1) {
                print parts[1]
            }
        }
    }
    ' "$file"
}

# toml_get_table_value <file> <full_section> <key>
# Returns value from [apt.repos.google-chrome] key = "value"
toml_get_table_value() {
    local file="$1"
    local section="$2"
    local key="$3"
    awk -v section="$section" -v key="$key" '
    BEGIN { in_section=0 }
    /^\[/ {
        gsub(/^\[|\]$/, "")
        if ($0 == section) {
            in_section=1
        } else {
            in_section=0
        }
        next
    }
    in_section {
        # Match key = "value" or key = value
        if (match($0, "^[[:space:]]*" key "[[:space:]]*=")) {
            val=$0
            sub(/^[^=]+=/, "", val)
            # Trim whitespace and quotes
            gsub(/^[[:space:]"'"'"']+|[[:space:]"'"'"']+$/, "", val)
            print val
            exit
        }
    }
    ' "$file"
}

# =============================================================================
# Homebrew path setup
# =============================================================================
setup_homebrew_path() {
    if [[ "$OS" == "darwin" ]]; then
        if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    elif [[ "$OS" == "linux" ]]; then
        if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
            eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
        fi
    fi
}
