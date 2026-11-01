#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 04_install_docker.sh
# Instalação do Docker CE Oficial no Ubuntu 22.04 / 24.04 / 26.04
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root ou usando sudo: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
fi
ADMIN_USER="${ADMIN_USER:-cluster}"

echo "=============================================================================="
echo "🐳 Instalando Docker Community Edition (Docker CE)..."
echo "=============================================================================="

# 1. Remover versões legadas conflitantes
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 2. Instalar dependências de chave e repositório
apt-get update
apt-get install -y ca-certificates curl gnupg

# 3. Importar chave GPG oficial da Docker Inc. com --yes para não travar
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Detectar versão do Ubuntu com fallback inteligente
CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-noble}")
# Se for versão futura ou sem repo no espelho, faz fallback para noble (24.04 LTS)
if [ "$CODENAME" != "jammy" ] && [ "$CODENAME" != "noble" ]; then
    echo "ℹ️ Verificando suporte para codename '$CODENAME'..."
    if ! curl -sfI "https://download.docker.com/linux/ubuntu/dists/$CODENAME/Release" >/dev/null; then
        echo "⚠️ Espelho para '$CODENAME' ainda não disponível. Usando suite 'noble' (LTS)."
        CODENAME="noble"
    fi
fi

# 5. Adicionar repositório APT
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 6. Instalar pacotes do Docker
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 7. Criar grupo docker se não existir e adicionar usuário admin
groupadd -f docker
if id "$ADMIN_USER" &>/dev/null; then
    usermod -aG docker "$ADMIN_USER"
    echo "👤 Usuário '$ADMIN_USER' adicionado ao grupo docker."
fi

# 8. Habilitar serviço
systemctl enable --now docker || true
echo "✅ Docker instalado com sucesso: $(docker --version)"
