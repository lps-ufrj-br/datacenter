#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 05_install_cuda.sh
# Instalação de Driver NVIDIA e CUDA Toolkit no Ubuntu 22.04 / 24.04 / 26.04
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root ou usando sudo: sudo bash $0"
    exit 1
fi

echo "=============================================================================="
echo "🎮 Verificando GPU NVIDIA..."
echo "=============================================================================="

if ! lspci 2>/dev/null | grep -i nvidia >/dev/null; then
    echo "⚠️ Nenhuma GPU NVIDIA física detectada neste nó."
    echo "Se este nó for uma VM sem GPU passthrough, a instalação do driver será pulada."
    read -p "Deseja continuar com a instalação do CUDA Toolkit mesmo assim? [s/N]: " -r resp || true
    if [[ ! "${resp:-}" =~ ^[sSyY]$ ]]; then
        echo "Operação abortada pelo usuário."
        exit 0
    fi
fi

# 1. Instalar headers do kernel
apt-get update
apt-get install -y linux-headers-$(uname -r) software-properties-common

# 2. Configurar repositório oficial da NVIDIA via cuda-keyring
CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-noble}")
UBUNTU_VER="ubuntu2404"
if [ "$CODENAME" = "jammy" ]; then
    UBUNTU_VER="ubuntu2204"
fi

KEYRING_DEB="cuda-keyring_1.1-1_all.deb"
KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/${UBUNTU_VER}/x86_64/${KEYRING_DEB}"

echo "📥 Baixando chave do repositório NVIDIA ($UBUNTU_VER)..."
wget -q -O "/tmp/$KEYRING_DEB" "$KEYRING_URL" || true
if [ -f "/tmp/$KEYRING_DEB" ]; then
    dpkg -i "/tmp/$KEYRING_DEB" || true
    rm -f "/tmp/$KEYRING_DEB"
    apt-get update
fi

# 3. Instalar Drivers e CUDA Toolkit
echo "📦 Instalando Drivers NVIDIA e CUDA Toolkit..."
if command -v ubuntu-drivers >/dev/null; then
    ubuntu-drivers install || true
fi

# Instala toolkit (fallback para nvidia-cuda-toolkit padrão do Ubuntu se o repo oficial falhar)
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-toolkit 2>/dev/null; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-cuda-toolkit
fi

# 4. Configurar variáveis de ambiente do CUDA em /etc/profile.d/cuda.sh
cat << 'EOF' > /etc/profile.d/cuda.sh
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
EOF
chmod 644 /etc/profile.d/cuda.sh

echo "=============================================================================="
echo "🔍 Verificando status NVIDIA..."
if command -v nvidia-smi >/dev/null; then
    nvidia-smi || true
fi
if command -v nvcc >/dev/null; then
    nvcc --version || true
fi
echo "✅ Instalação do CUDA concluída! Recomenda-se reiniciar a máquina."
