#!/usr/bin/env bash
# =====================================================
# Bootstrap hôte Debian/Ubuntu : Docker, UFW, fail2ban,
# SSH durci. Idempotent.
# =====================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
# Charger les variables d'environnement (ID, VERSION_CODENAME)
. /etc/os-release
echo "OS Détecté : $ID"
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
  echo "OS non supporté : $ID"
  exit 1
fi

# Charger VERSION_CODENAME
VERSION_CODENAME=$(echo $VERSION | cut -d'(' -f2 | cut -d')' -f1)
echo "Version : $VERSION_CODENAME"

echo "Mise à jour du système et installation des paquets essentiels..."

apt update && apt -y upgrade
apt -y install ca-certificates curl gnupg ufw fail2ban unattended-upgrades rsync

# Docker
# install -m 0755 -d /etc/apt/keyrings
# curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# echo "deb [signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release; echo $VERSION_CODENAME) stable" \
#   > /etc/apt/sources.list.d/docker.list
# apt update && apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Detect OS
if [[ "$ID" == "ubuntu" ]]; then
  DOCKER_REPO="https://download.docker.com/linux/ubuntu"
elif [[ "$ID" == "debian" ]]; then
  DOCKER_REPO="https://download.docker.com/linux/debian"
else
  echo "Unsupported OS: $ID"
  exit 1
fi

# Docker
if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "$DOCKER_REPO/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [signed-by=/etc/apt/keyrings/docker.gpg] $DOCKER_REPO $(. /etc/os-release; echo $VERSION_CODENAME) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt update && apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# UFW : SSH + 80/443 + WireGuard UDP
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 51820/udp
ufw --force enable

# Installer SSH si absent
if ! dpkg -l | grep -q openssh-server; then
  apt -y install openssh-server
fi

# Vérifier que le fichier existe avant de le modifier
SSH_CONFIG="/etc/ssh/sshd_config"

if [ -f "$SSH_CONFIG" ]; then
  # Backup (une seule fois)
  [ -f "${SSH_CONFIG}.bak" ] || cp "$SSH_CONFIG" "${SSH_CONFIG}.bak"

  # SSH durcissement
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSH_CONFIG"
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSH_CONFIG"
  sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "$SSH_CONFIG"

  # S'assurer que les ligne existent si elles étaient absentes
  grep -q "^PermitRootLogin" "$SSH_CONFIG" || echo "PermitRootLogin prohibit-password" >> "$SSH_CONFIG"
  grep -q "^PasswordAuthentication" "$SSH_CONFIG" || echo "PasswordAuthentication no" >> "$SSH_CONFIG"
  grep -q "^X11Forwarding" "$SSH_CONFIG" || echo "X11Forwarding no" >> "$SSH_CONFIG"

  # Activer et redémarrer SSH (compatible Ubuntu/Debian)
  systemctl enable ssh || true
  systemctl restart ssh || systemctl restart sshd

  echo "SSH durci et redémarré."
else
  echo "Fichier sshd_config introuvable. SSH non durci."
  exit 1
fi

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
