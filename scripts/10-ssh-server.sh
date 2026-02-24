#!/usr/bin/env bash
# =============================================================================
# 10-ssh-server.sh — Configure openssh-server (Linux only)
# Writes a drop-in config that survives package upgrades.
# =============================================================================

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"

[[ "$OS" == "linux" ]] || { log_info "Skipping SSH server config (not Linux)"; exit 0; }

log_section "SSH Server"
check_not_root

DROP_IN="/etc/ssh/sshd_config.d/99-custom.conf"

# =============================================================================
# Ensure openssh-server is installed
# =============================================================================
if ! apt_installed openssh-server; then
    log_info "Installing openssh-server..."
    sudo apt-get install -y openssh-server
    log_success "openssh-server installed"
else
    log_success "openssh-server already installed"
fi

# =============================================================================
# Write drop-in config
# =============================================================================
log_info "Writing SSH drop-in config to $DROP_IN..."
sudo tee "$DROP_IN" > /dev/null <<'EOF'
# Custom SSH server configuration — managed by bonfire
# This file is loaded after /etc/ssh/sshd_config (override order)

PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
MaxAuthTries 5
MaxSessions 10
X11Forwarding no

# Only allow specific users (uncomment and adjust as needed)
# AllowUsers yourusername

# Use more secure key exchange algorithms
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group14-sha256
EOF

# sshd -t requires /run/sshd to exist (normally created on first start)
sudo mkdir -p /run/sshd

# Validate config before restarting
log_info "Validating SSH config..."
if sudo sshd -t; then
    log_success "SSH config validation passed"
    log_info "Restarting sshd..."
    sudo systemctl restart ssh
    log_success "SSH server restarted"
else
    log_error "SSH config validation failed — not restarting sshd"
    sudo rm -f "$DROP_IN"
    exit 1
fi

# Ensure SSH service is enabled at boot
if ! sudo systemctl is-enabled ssh &>/dev/null; then
    log_info "Enabling SSH service at boot..."
    sudo systemctl enable ssh
fi

# =============================================================================
# Set up ~/.ssh/ directory with correct permissions
# =============================================================================
log_info "Setting up ~/.ssh/ directory..."
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ -f "$HOME/.ssh/authorized_keys" ]]; then
    chmod 600 "$HOME/.ssh/authorized_keys"
    log_success "~/.ssh/authorized_keys permissions set"
else
    touch "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
    log_warn "Created empty ~/.ssh/authorized_keys"
fi

# =============================================================================
# Summary
# =============================================================================
log_success "SSH server configured"
log_info "Status: $(sudo systemctl is-active ssh)"
echo ""
log_warn "PasswordAuthentication is DISABLED. To connect from another machine:"
echo ""
echo "  1. Temporarily enable password auth on this machine:"
echo "       sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' $DROP_IN"
echo "       sudo systemctl reload ssh"
echo ""
echo "  2. Copy your public key from the other machine:"
echo "       ssh-copy-id $USER@$(hostname -I | awk '{print $1}')"
echo ""
echo "  3. Disable password auth again on this machine:"
echo "       sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' $DROP_IN"
echo "       sudo systemctl reload ssh"
echo ""
echo "  Or add the key manually on this machine:"
echo "       echo \"<your public key>\" >> ~/.ssh/authorized_keys"
