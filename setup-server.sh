#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "============================================"
echo " Server Bootstrap - Ubuntu 22.04"
echo "============================================"

# === 1. System Update & Upgrade ===
echo ""
echo "[1/4] Updating system..."
apt-get update
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# === 2. Install Packages ===
echo ""
echo "[2/4] Installing packages..."

# openssh-server: only if not installed
if ! dpkg -l openssh-server 2>/dev/null | grep -q '^ii'; then
    echo "  --> openssh-server not found, installing..."
    apt-get install -y openssh-server
else
    echo "  --> openssh-server already installed, skipping."
fi

# fail2ban: always install
apt-get install -y fail2ban

# === 3. SSH Hardening ===
echo ""
echo "[3/4] Configuring SSH..."

# Setup root authorized key
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

grep -qxF 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZ4aWoS2hWar+5zW13Ish3Up+LpPBjpKP8knqfgibaV mcp-client' /root/.ssh/authorized_keys || \
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZ4aWoS2hWar+5zW13Ish3Up+LpPBjpKP8knqfgibaV mcp-client' >> /root/.ssh/authorized_keys

chown -R root:root /root/.ssh

# Write 99-mcp.conf
cat > /etc/ssh/sshd_config.d/99-mcp.conf << 'EOF'
# Managed by mcp-client
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password

# Allow password auth for non-root users
Match User *,!root
    PasswordAuthentication yes
    KbdInteractiveAuthentication yes
EOF

# Neutralize 50-cloud-init.conf if exists
if [ -f /etc/ssh/sshd_config.d/50-cloud-init.conf ]; then
    echo "  --> Neutralizing 50-cloud-init.conf..."
    echo "# Neutralized - overridden by 99-mcp.conf" > /etc/ssh/sshd_config.d/50-cloud-init.conf
fi

# Validate & reload SSH
sshd -t
systemctl enable ssh
systemctl reload ssh
echo "  --> SSH configured and reloaded."

# === 4. fail2ban ===
echo ""
echo "[4/4] Configuring fail2ban..."

# Write jail.local (never edit jail.conf directly)
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban for 10 minutes after 5 failures within 10 minutes
bantime  = 10m
findtime = 10m
maxretry = 5

[sshd]
enabled = true
backend = systemd
EOF

systemctl enable fail2ban
systemctl restart fail2ban
echo "  --> fail2ban configured and started."

# === 5. Verify ===
echo ""
echo "============================================"
echo " Verification"
echo "============================================"

echo ""
echo "--- authorized_keys ---"
cat /root/.ssh/authorized_keys

echo ""
echo "--- 99-mcp.conf ---"
cat /etc/ssh/sshd_config.d/99-mcp.conf

echo ""
echo "--- sshd effective settings ---"
sshd -T 2>/dev/null | grep -E '^(permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication)\b'

echo ""
echo "--- fail2ban service ---"
systemctl status fail2ban --no-pager

echo ""
echo "--- fail2ban sshd jail ---"
sleep 2
fail2ban-client status sshd

echo ""
echo "============================================"
echo " Bootstrap complete!"
echo "============================================"
