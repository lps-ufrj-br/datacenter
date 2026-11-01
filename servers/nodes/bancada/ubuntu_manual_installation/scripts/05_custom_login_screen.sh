#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 06_custom_login_screen.sh
# Customização da Tela de Login do GDM (Ocultar Lista de Usuários no GDM 46+)
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root ou usando sudo: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================================================="
echo "🖥️  Configurando Tela de Login do GDM (Dconf)..."
echo "=============================================================================="

# Instala dconf-cli caso não esteja presente
apt-get install -y dconf-cli

# 1. Configurar perfil do GDM
mkdir -p /etc/dconf/profile
if [ -f "$SCRIPT_DIR/files/gdm" ]; then
    cp "$SCRIPT_DIR/files/gdm" /etc/dconf/profile/gdm
else
    cat << 'EOF' > /etc/dconf/profile/gdm
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF
fi

# 2. Configurar chave de desabilitação da lista de usuários
mkdir -p /etc/dconf/db/gdm.d
if [ -f "$SCRIPT_DIR/files/00-login-screen" ]; then
    cp "$SCRIPT_DIR/files/00-login-screen" /etc/dconf/db/gdm.d/00-login-screen
else
    cat << 'EOF' > /etc/dconf/db/gdm.d/00-login-screen
[org/gnome/login-screen]
disable-user-list=true
EOF
fi

# 3. Atualizar base dconf
dconf update
echo "✅ Tela de login do GDM atualizada com sucesso!"
