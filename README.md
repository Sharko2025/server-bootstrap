# server-bootstrap

A one-shot bootstrap script for hardening a fresh Ubuntu 22.04 server with secure SSH configuration and brute-force protection.

## Features

- **Unattended execution** — fully non-interactive, no prompts including kernel upgrade dialogs
- **System update** — runs `apt update` and `apt upgrade` automatically
- **Smart package install** — checks if `openssh-server` is already installed before installing; always installs `fail2ban`
- **SSH hardening** via drop-in config (`/etc/ssh/sshd_config.d/99-mcp.conf`):
  - Root login via **SSH key only**
  - Non-root users can login via **password or key**
  - Neutralizes `50-cloud-init.conf` to prevent conflicts
- **fail2ban** — installed, enabled and configured out of the box
- **Verification output** — prints effective SSH settings and fail2ban jail status at the end

## Auth Matrix

| User | Password | SSH Key |
|------|----------|---------|
| `root` | ❌ Blocked | ✅ Allowed |
| Any other user | ✅ Allowed | ✅ Allowed |

## Requirements

- Ubuntu 22.04 LTS
- Run as root or with `sudo`

## Usage

```bash
sudo bash setup-server.sh
```

## What It Configures

### SSH — `/etc/ssh/sshd_config.d/99-mcp.conf`
```
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password

Match User *,!root
    PasswordAuthentication yes
    KbdInteractiveAuthentication yes
```

### fail2ban — `/etc/fail2ban/jail.local`
```
[DEFAULT]
bantime  = 10m
findtime = 10m
maxretry = 5

[sshd]
enabled = true
backend = systemd
```

## Useful Commands After Bootstrap

```bash
# Check effective SSH config
sudo sshd -T | grep -iE 'password|pubkey|kbd|rootlogin'

# Check fail2ban status
sudo fail2ban-client status sshd

# Check banned IPs
sudo fail2ban-client status sshd | grep "Banned IP"
```
