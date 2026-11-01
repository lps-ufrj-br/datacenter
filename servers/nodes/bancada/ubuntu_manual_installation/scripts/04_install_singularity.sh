#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 03_install_singularity.sh
# Instalação do SingularityCE (Community Edition Oficial) no Ubuntu
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root ou usando sudo: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SINGULARITY_VERSION="4.6.0"

echo "=============================================================================="
echo "📦 Instalando SingularityCE v${SINGULARITY_VERSION}..."
echo "=============================================================================="

# 1. Instalar dependências essenciais
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    libseccomp-dev \
    pkg-config \
    squashfs-tools \
    cryptsetup \
    uidmap \
    wget \
    curl \
    ca-certificates

# 2. Detectar versão do Ubuntu (ex: noble para 24.04, resolute para 26.04, jammy para 22.04)
CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-noble}")
DEB_NAME="singularity-ce_${SINGULARITY_VERSION}-${CODENAME}_amd64.deb"
DOWNLOAD_URL="https://github.com/sylabs/singularity/releases/download/v${SINGULARITY_VERSION}/${DEB_NAME}"

echo "📥 Baixando pacote oficial Sylabs para $CODENAME..."
if ! wget -q -O "/tmp/$DEB_NAME" "$DOWNLOAD_URL"; then
    echo "⚠️ Pacote específico para '$CODENAME' não encontrado. Tentando versão 'noble'..."
    DEB_NAME="singularity-ce_${SINGULARITY_VERSION}-noble_amd64.deb"
    DOWNLOAD_URL="https://github.com/sylabs/singularity/releases/download/v${SINGULARITY_VERSION}/${DEB_NAME}"
    wget -q -O "/tmp/$DEB_NAME" "$DOWNLOAD_URL"
fi

# 3. Instalar o pacote .deb oficial com resolução de dependências
echo "📦 Instalando /tmp/$DEB_NAME..."
apt-get install -y "/tmp/$DEB_NAME"
rm -f "/tmp/$DEB_NAME"

echo "ℹ️ Singularity instalado com sucesso:"
singularity --version

# 4. Configurar fakeroot para os usuários de domínio LDAP
if [ -f "$SCRIPT_DIR/08_configure_singularity.py" ]; then
    echo "⚙️ Configurando permissões de fakeroot..."
    python3 "$SCRIPT_DIR/08_configure_singularity.py" || true
fi

echo "✅ Singularity configurado com sucesso!"
