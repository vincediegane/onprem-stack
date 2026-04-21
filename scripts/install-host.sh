#!/usr/bin/env bash
# =====================================================
# Bootstrap hôte Debian/Ubuntu : Docker, UFW, fail2ban,
# SSH durci. Idempotent.
# =====================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }

apt update && apt -y upgrade
apt -y install ca-certificates curl gnupg ufw fail2ban unattended-upgrades rsync

# Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release; echo $VERSION_CODENAME) stable" \
  > /etc/apt/sources.list.d/docker.list
apt update && apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# UFW : SSH + 80/443 + WireGuard UDP
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 51820/udp
ufw --force enable

# SSH durci
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
systemctl reload ssh

# Fail2ban
cat >/etc/fail2ban/jail.d/onprem.local << 'INI'
[sshd]
enabled = true
maxretry = 4
findtime = 10m
bantime = 1h

[traefik-auth]
enabled = true
filter = traefik-auth
port = http,https
logpath = /var/lib/docker/containers/*/*.log
maxretry = 5
INI

cat >/etc/fail2ban/filter.d/traefik-auth.conf << 'INI'
[Definition]
failregex = ^.*"ClientHost":"<HOST>".*"DownstreamStatus":401.*$
INI
systemctl enable --now fail2ban

# Updates auto
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "Done. Reboot recommandé."
