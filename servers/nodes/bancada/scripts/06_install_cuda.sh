#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 06_install_cuda.sh
# NVIDIA Driver and CUDA Toolkit Installation on Ubuntu 22.04 / 24.04 / 26.04
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root or using sudo: sudo bash $0"
    exit 1
fi

echo "=============================================================================="
echo "🎮 Checking for NVIDIA GPU..."
echo "=============================================================================="

if ! lspci 2>/dev/null | grep -i nvidia >/dev/null; then
    echo "⚠️ No physical NVIDIA GPU detected on this node."
    echo "If this node is a VM without GPU passthrough, driver installation will be skipped."
    read -p "Do you want to proceed with CUDA Toolkit installation anyway? [y/N]: " -r resp || true
    if [[ ! "${resp:-}" =~ ^[yYsS]$ ]]; then
        echo "Operation aborted by user."
        exit 0
    fi
fi

# 1. Install kernel headers and repository tools
apt-get update
apt-get install -y linux-headers-$(uname -r) software-properties-common

# 2. Configure NVIDIA official repository via cuda-keyring
CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-noble}")
UBUNTU_VER="ubuntu2404"
if [ "$CODENAME" = "jammy" ]; then
    UBUNTU_VER="ubuntu2204"
fi

KEYRING_DEB="cuda-keyring_1.1-1_all.deb"
KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/${UBUNTU_VER}/x86_64/${KEYRING_DEB}"

echo "📥 Downloading NVIDIA repository keyring ($UBUNTU_VER)..."
wget -q -O "/tmp/$KEYRING_DEB" "$KEYRING_URL" || true
if [ -f "/tmp/$KEYRING_DEB" ]; then
    dpkg -i "/tmp/$KEYRING_DEB" || true
    rm -f "/tmp/$KEYRING_DEB"
    apt-get update
fi

# 3. Install Drivers and CUDA Toolkit
echo "📦 Installing NVIDIA Drivers and CUDA Toolkit..."
if command -v ubuntu-drivers >/dev/null; then
    ubuntu-drivers install || true
fi

# Install toolkit (fallback to default ubuntu package if official fails)
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-toolkit 2>/dev/null; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-cuda-toolkit
fi

# 4. Configure CUDA environment variables in /etc/profile.d/cuda.sh
cat << 'EOF' > /etc/profile.d/cuda.sh
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
EOF
chmod 644 /etc/profile.d/cuda.sh

echo "=============================================================================="
echo "🔍 Checking NVIDIA status..."
if command -v nvidia-smi >/dev/null; then
    nvidia-smi || true
fi
if command -v nvcc >/dev/null; then
    nvcc --version || true
fi
echo "✅ CUDA installation completed successfully! A system reboot is recommended."
