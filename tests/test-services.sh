#!/usr/bin/env bash
# =============================================================================
# test-services.sh — Test running services (SSH, Docker, etc.)
# =============================================================================

# shellcheck source=../scripts/_lib.sh
source "$(dirname "$0")/../scripts/_lib.sh"

log_section "Test: Services"

PASS=0
FAIL=0
WARN=0

check_service_active() {
    local name="$1"
    local service="$2"
    if sudo systemctl is-active "$service" &>/dev/null; then
        log_success "PASS: $name is running (systemctl: $service)"
        PASS=$((PASS + 1))
    else
        log_error "FAIL: $name is not running (systemctl: $service)"
        FAIL=$((FAIL + 1))
    fi
}

check_service_enabled() {
    local name="$1"
    local service="$2"
    if sudo systemctl is-enabled "$service" &>/dev/null; then
        log_success "PASS: $name is enabled at boot"
        PASS=$((PASS + 1))
    else
        log_warn "WARN: $name is not enabled at boot"
        WARN=$((WARN + 1))
    fi
}

check_port_listening() {
    local name="$1"
    local port="$2"
    if ss -tlnp 2>/dev/null | grep -q ":${port} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
        log_success "PASS: $name is listening on port $port"
        PASS=$((PASS + 1))
    else
        log_warn "WARN: $name does not appear to be listening on port $port"
        WARN=$((WARN + 1))
    fi
}

# =============================================================================
# Linux services
# =============================================================================
if [[ "$OS" == "linux" ]]; then
    # SSH server
    log_info "Checking SSH server..."
    check_service_active "SSH server" "ssh"
    check_service_enabled "SSH server" "ssh"
    check_port_listening "SSH" "22"

    # Verify SSH config
    if [[ -f /etc/ssh/sshd_config.d/99-custom.conf ]]; then
        log_success "PASS: SSH drop-in config exists"
        PASS=$((PASS + 1))

        # Validate config
        if sudo sshd -t &>/dev/null; then
            log_success "PASS: SSH config is valid"
            PASS=$((PASS + 1))
        else
            log_error "FAIL: SSH config validation failed"
            FAIL=$((FAIL + 1))
        fi

        # Check key settings
        if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config.d/99-custom.conf; then
            log_success "PASS: PasswordAuthentication disabled"
            PASS=$((PASS + 1))
        else
            log_warn "WARN: PasswordAuthentication may not be disabled"
            WARN=$((WARN + 1))
        fi

        if grep -q "PermitRootLogin no" /etc/ssh/sshd_config.d/99-custom.conf; then
            log_success "PASS: PermitRootLogin disabled"
            PASS=$((PASS + 1))
        else
            log_warn "WARN: PermitRootLogin may not be disabled"
            WARN=$((WARN + 1))
        fi
    else
        log_warn "WARN: SSH drop-in config not found at /etc/ssh/sshd_config.d/99-custom.conf"
        WARN=$((WARN + 1))
    fi

    # ~/.ssh permissions
    log_info "Checking ~/.ssh permissions..."
    if [[ -d "$HOME/.ssh" ]]; then
        ssh_perms="$(stat -c "%a" "$HOME/.ssh")"
        if [[ "$ssh_perms" == "700" ]]; then
            log_success "PASS: ~/.ssh permissions are 700"
            PASS=$((PASS + 1))
        else
            log_error "FAIL: ~/.ssh permissions are $ssh_perms (expected 700)"
            FAIL=$((FAIL + 1))
        fi
    fi

    if [[ -f "$HOME/.ssh/authorized_keys" ]]; then
        ak_perms="$(stat -c "%a" "$HOME/.ssh/authorized_keys")"
        if [[ "$ak_perms" == "600" ]]; then
            log_success "PASS: ~/.ssh/authorized_keys permissions are 600"
            PASS=$((PASS + 1))
        else
            log_error "FAIL: ~/.ssh/authorized_keys permissions are $ak_perms (expected 600)"
            FAIL=$((FAIL + 1))
        fi

        # Check if any keys are configured
        key_count="$(grep -c "ssh-" "$HOME/.ssh/authorized_keys" 2>/dev/null || echo 0)"
        if [[ "$key_count" -gt 0 ]]; then
            log_success "PASS: $key_count public key(s) in authorized_keys"
            PASS=$((PASS + 1))
        else
            log_warn "WARN: No public keys in ~/.ssh/authorized_keys — add your key before logging out"
            WARN=$((WARN + 1))
        fi
    fi

    # Podman (rootless — no daemon or group to check)
    log_info "Checking Podman..."
    if command_exists podman; then
        log_success "PASS: podman available"
        PASS=$((PASS + 1))

        if podman info &>/dev/null 2>&1; then
            log_success "PASS: podman info succeeds (rootless)"
            PASS=$((PASS + 1))
        else
            log_warn "WARN: podman info failed"
            WARN=$((WARN + 1))
        fi
    else
        log_warn "WARN: podman not installed"
        WARN=$((WARN + 1))
    fi

elif [[ "$OS" == "darwin" ]]; then
    log_info "Checking macOS services..."

    # LaunchAgent for key remapping
    LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.local.KeyRemapping.plist"
    if [[ -f "$LAUNCH_AGENT" ]]; then
        log_success "PASS: Key remapping LaunchAgent installed"
        PASS=$((PASS + 1))
        if launchctl list 2>/dev/null | grep -q "com.local.KeyRemapping"; then
            log_success "PASS: Key remapping LaunchAgent is loaded"
            PASS=$((PASS + 1))
        else
            log_warn "WARN: Key remapping LaunchAgent not loaded (run: launchctl load $LAUNCH_AGENT)"
            WARN=$((WARN + 1))
        fi
    else
        log_warn "WARN: Key remapping LaunchAgent not found"
        WARN=$((WARN + 1))
    fi
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
log_section "Test Results: Services"
printf "PASS: %d   WARN: %d   FAIL: %d\n" "$PASS" "$WARN" "$FAIL"

[[ $FAIL -eq 0 ]]
