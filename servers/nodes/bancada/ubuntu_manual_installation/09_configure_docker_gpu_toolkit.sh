#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 09_configure_docker_gpu_toolkit.sh
# Configuração do NVIDIA Container Toolkit para Docker
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root ou usando sudo: sudo bash $0"
    exit 1
fi

echo "=============================================================================="
echo "🚀 Configurando NVIDIA Container Toolkit..."
echo "=============================================================================="

# 1. Configurar chave GPG e repositório
install -m 0755 -d /usr/share/keyrings
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
chmod a+r /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

# 2. Instalar o toolkit
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit

# 3. Configurar runtime do Docker
nvidia-ctk runtime configure --runtime=docker

if [ ! -f /.dockerenv ]; then
    systemctl restart docker || true
fi

echo "✅ NVIDIA Container Toolkit configurado com sucesso!"
