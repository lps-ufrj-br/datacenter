#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 03_install_docker.sh
# Full Installation and Configuration of Docker CE on Ubuntu 22.04 / 24.04 / 26.04
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root or using sudo: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
elif [ -f "$SCRIPT_DIR/../config.env" ]; then
    source "$SCRIPT_DIR/../config.env"
fi
ADMIN_USER="${ADMIN_USER:-cluster}"

echo "=============================================================================="
echo "🐳 Installing and Configuring Docker Community Edition (Docker CE)..."
echo "=============================================================================="

# 1. Remove conflicting legacy packages
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 2. Install repository and key management dependencies
apt-get update
apt-get install -y ca-certificates curl gnupg

# 3. Import Docker Inc. official GPG key non-interactively
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Detect Ubuntu codename with fallback
CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-noble}")
if [ "$CODENAME" != "jammy" ] && [ "$CODENAME" != "noble" ]; then
    echo "ℹ️ Checking repository mirror support for codename '$CODENAME'..."
    if ! curl -sfI "https://download.docker.com/linux/ubuntu/dists/$CODENAME/Release" >/dev/null; then
        echo "⚠️ Repository mirror for '$CODENAME' not available yet. Falling back to 'noble' (LTS)."
        CODENAME="noble"
    fi
fi

# 5. Add Docker APT repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 6. Install Docker packages
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 7. Create docker group and add admin user
groupadd -f docker
if id "$ADMIN_USER" &>/dev/null; then
    usermod -aG docker "$ADMIN_USER"
    echo "👤 User '$ADMIN_USER' added to docker group."
fi

# 8. Configure daemon.json with log rotation to prevent disk exhaustion
mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ]; then
    cat << 'EOF' > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF
    echo "⚙️ Configured /etc/docker/daemon.json with log rotation (max 50m)."
fi

# 9. Configure Docker total cleanup on reboot systemd service
SERVICE_FILE="/etc/systemd/system/docker-cleanup-reboot.service"
cat << 'EOF' > "$SERVICE_FILE"
[Unit]
Description=Total Docker Cleanup on Reboot
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker system prune -a --volumes -f

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$SERVICE_FILE"

# 10. Enable and start services
if [ ! -f /.dockerenv ]; then
    systemctl daemon-reload
    systemctl enable docker-cleanup-reboot.service
    systemctl enable --now docker || true
    systemctl restart docker || true
fi

echo "✅ Docker successfully installed and configured: $(docker --version)"
