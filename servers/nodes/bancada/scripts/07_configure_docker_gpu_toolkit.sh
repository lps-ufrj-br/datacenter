#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 07_configure_docker_gpu_toolkit.sh
# NVIDIA Container Toolkit Configuration for Docker (--gpus all support)
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root or using sudo: sudo bash $0"
    exit 1
fi

echo "=============================================================================="
echo "🚀 Configuring NVIDIA Container Toolkit for Docker..."
echo "=============================================================================="

if ! lspci 2>/dev/null | grep -i nvidia >/dev/null; then
    echo "⚠️ No physical NVIDIA GPU detected on this node."
    echo "Skipping NVIDIA Container Toolkit configuration."
    exit 0
fi

# Ensure curl and gnupg are installed
apt-get update -qq
apt-get install -y --no-install-recommends curl gnupg

# 1. Configure GPG key and APT repository
install -m 0755 -d /usr/share/keyrings
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
chmod a+r /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

# 2. Install the toolkit
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit

# 3. Configure Docker runtime
nvidia-ctk runtime configure --runtime=docker

if [ ! -f /.dockerenv ]; then
    systemctl restart docker || true
fi

echo "✅ NVIDIA Container Toolkit successfully configured!"
