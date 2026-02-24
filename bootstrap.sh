#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Single entry point for full bonfire setup
#
# Usage:
#   ./bootstrap.sh                   # Full setup (prompts for confirmation)
#   ./bootstrap.sh --yes             # Full setup (no prompts)
#   ./bootstrap.sh --from 03         # Resume from a specific step (skips earlier ones)
#   ./bootstrap.sh --from apt-repos  # Same, matched by keyword
#   ./bootstrap.sh --only mise       # Run only the mise script
#   ./bootstrap.sh --only dotfiles   # Run only the dotfiles script
#   ./bootstrap.sh --only "apt mise" # Run multiple specific scripts
#   ./bootstrap.sh --list            # List all available scripts
#   ./bootstrap.sh --help            # Show this help
# =============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=scripts/_lib.sh
source "$REPO_DIR/scripts/_lib.sh"

# =============================================================================
# Argument parsing
# =============================================================================
AUTO_YES=0
ONLY_FILTER=""
FROM_STEP=""
DO_LIST=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)
            AUTO_YES=1
            shift
            ;;
        --only)
            ONLY_FILTER="$2"
            shift 2
            ;;
        --from)
            FROM_STEP="$2"
            shift 2
            ;;
        --list)
            DO_LIST=1
            shift
            ;;
        --help|-h)
            grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# =============================================================================
# Collect scripts
# =============================================================================
SCRIPTS_DIR="$REPO_DIR/scripts"

# All numbered scripts in order
ALL_SCRIPTS=()
while IFS= read -r script; do
    ALL_SCRIPTS+=("$script")
done < <(find "$SCRIPTS_DIR" -maxdepth 1 -name '[0-9][0-9]-*.sh' | sort)

if [[ $DO_LIST -eq 1 ]]; then
    echo "Available scripts:"
    for script in "${ALL_SCRIPTS[@]}"; do
        name="$(basename "$script" .sh)"
        printf "  %s\n" "$name"
    done
    exit 0
fi

# =============================================================================
# Filter scripts
# =============================================================================
SCRIPTS_TO_RUN=()
if [[ -n "$ONLY_FILTER" ]]; then
    # --only: run just the named script(s)
    for keyword in $ONLY_FILTER; do
        found=0
        for script in "${ALL_SCRIPTS[@]}"; do
            if [[ "$(basename "$script")" == *"$keyword"* ]]; then
                SCRIPTS_TO_RUN+=("$script")
                found=1
            fi
        done
        if [[ $found -eq 0 ]]; then
            log_warn "No script matching keyword: $keyword"
        fi
    done
    if [[ ${#SCRIPTS_TO_RUN[@]} -eq 0 ]]; then
        log_error "No matching scripts found for filter: $ONLY_FILTER"
        exit 1
    fi
elif [[ -n "$FROM_STEP" ]]; then
    # --from: skip all scripts before the matching one
    found=0
    for script in "${ALL_SCRIPTS[@]}"; do
        name="$(basename "$script")"
        if [[ $found -eq 0 ]]; then
            if [[ "$name" == *"$FROM_STEP"* ]]; then
                found=1
            fi
        fi
        [[ $found -eq 1 ]] && SCRIPTS_TO_RUN+=("$script")
    done
    if [[ ${#SCRIPTS_TO_RUN[@]} -eq 0 ]]; then
        log_error "No script matching --from keyword: $FROM_STEP"
        log_info "Run './bootstrap.sh --list' to see available scripts"
        exit 1
    fi
else
    SCRIPTS_TO_RUN=("${ALL_SCRIPTS[@]}")
fi

# =============================================================================
# Banner
# =============================================================================
clear
printf "${C_BOLD}${C_BLUE}"
cat <<'BANNER'
  ██████╗  ██████╗ ███╗   ██╗███████╗██╗██████╗ ███████╗
  ██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║██╔══██╗██╔════╝
  ██████╔╝██║   ██║██╔██╗ ██║█████╗  ██║██████╔╝█████╗
  ██╔══██╗██║   ██║██║╚██╗██║██╔══╝  ██║██╔══██╗██╔══╝
  ██████╔╝╚██████╔╝██║ ╚████║██║     ██║██║  ██║███████╗
  ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝
BANNER
printf "${C_RESET}\n"

printf "${C_BOLD}  Platform: ${C_CYAN}%s (%s)${C_RESET}\n" "$OS" "$DISTRO"
printf "${C_BOLD}  Repo:     ${C_CYAN}%s${C_RESET}\n" "$REPO_DIR"
printf "${C_BOLD}  Scripts:  ${C_CYAN}%d to run${C_RESET}\n\n" "${#SCRIPTS_TO_RUN[@]}"

# Script descriptions
declare -A SCRIPT_DESC=(
    [01-system-update.sh]="Update system packages / Xcode CLT"
    [02-homebrew.sh]="Install Homebrew + formulae (+ casks on macOS)"
    [03-apt-repos.sh]="Add third-party apt repos (Chrome, VSCode, Docker)"
    [04-apt-packages.sh]="Install apt packages"
    [05-flatpak.sh]="Install Flatpak apps (Obsidian, Slack)"
    [06-appimages.sh]="Download & install AppImages (Snipaste)"
    [07-mise.sh]="Install mise + dev tools (Node, Python, fzf, eza…)"
    [08-shell-setup.sh]="Install Zsh and set as default shell"
    [09-dotfiles.sh]="Symlink dotfiles via GNU Stow"
    [10-ssh-server.sh]="Configure openssh-server with hardened settings"
    [11-desktop-settings.sh]="Apply desktop prefs + CapsLock/Esc swap"
    [12-verify.sh]="Run all checks and print summary"
)

# List what will run
printf "${C_BOLD}Scripts to run:${C_RESET}\n"
for script in "${SCRIPTS_TO_RUN[@]}"; do
    name="$(basename "$script")"
    desc="${SCRIPT_DESC[$name]:-}"
    printf "  ${C_CYAN}%-28s${C_RESET} %s\n" "$name" "$desc"
done
echo ""

# =============================================================================
# Safety checks
# =============================================================================
check_not_root

# =============================================================================
# Confirm
# =============================================================================
if [[ $AUTO_YES -eq 0 ]]; then
    printf "${C_YELLOW}${C_BOLD}Proceed with setup? [y/N] ${C_RESET}"
    read -r answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# =============================================================================
# Initialize log
# =============================================================================
mkdir -p "$(dirname "$LOG_FILE")"
echo "=== bootstrap.sh started at $(date) ===" >> "$LOG_FILE"
echo "OS=$OS DISTRO=$DISTRO" >> "$LOG_FILE"

# =============================================================================
# Run scripts
# =============================================================================
FAILED_SCRIPTS=()
COMPLETED_SCRIPTS=()

for script in "${SCRIPTS_TO_RUN[@]}"; do
    script_name="$(basename "$script")"
    log_section "Running: $script_name"

    START_TIME="$SECONDS"

    if bash "$script"; then
        ELAPSED=$((SECONDS - START_TIME))
        log_success "$script_name completed in ${ELAPSED}s"
        COMPLETED_SCRIPTS+=("$script_name")
    else
        EXIT_CODE=$?
        log_error "$script_name FAILED (exit code $EXIT_CODE)"
        FAILED_SCRIPTS+=("$script_name")

        if [[ $AUTO_YES -eq 0 ]]; then
            printf "${C_YELLOW}Continue with remaining scripts? [y/N] ${C_RESET}"
            read -r continue_answer
            if [[ "$continue_answer" != "y" && "$continue_answer" != "Y" ]]; then
                log_error "Stopping at user request"
                break
            fi
        else
            log_warn "Continuing despite failure (--yes mode)"
        fi
    fi
done

# =============================================================================
# Final summary
# =============================================================================
log_section "Bootstrap Complete"

printf "${C_GREEN}${C_BOLD}  Completed (%d):${C_RESET}\n" "${#COMPLETED_SCRIPTS[@]}"
for s in "${COMPLETED_SCRIPTS[@]}"; do
    printf "${C_GREEN}    ✓ %s${C_RESET}\n" "$s"
done

if [[ ${#FAILED_SCRIPTS[@]} -gt 0 ]]; then
    printf "\n${C_RED}${C_BOLD}  Failed (%d):${C_RESET}\n" "${#FAILED_SCRIPTS[@]}"
    for s in "${FAILED_SCRIPTS[@]}"; do
        printf "${C_RED}    ✗ %s${C_RESET}\n" "$s"
    done
    echo ""
    log_warn "Some scripts failed. Check $LOG_FILE for details."
    log_warn "Fix issues and re-run: bash bootstrap.sh --only <script-keyword>"
    exit 1
else
    echo ""
    log_success "All scripts completed successfully!"
    log_info "Log file: $LOG_FILE"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Restart your terminal (or run: exec zsh)"
    log_info "  2. Configure git: git config --global user.name 'Your Name'"
    log_info "  3. Configure git: git config --global user.email 'you@example.com'"
    log_info "  4. Add your SSH key to ~/.ssh/authorized_keys"
    log_info "  5. Run: make test  (to verify everything)"
fi
