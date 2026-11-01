#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 01_setup_network.sh
# Configuração de Rede Estática (Netplan Moderno para Ubuntu 22.04 / 24.04 / 26.04)
# ==============================================================================
set -euo pipefail

# Garante privilégios de root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root ou usando sudo: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
fi

# Parâmetros opcionais via CLI: $1 = IP (ou lê de config.env)
NODE_IP="${1:-${NODE_IP:-}}"
NODE_HOSTNAME="${2:-${NODE_HOSTNAME:-bancada01}}"
GATEWAY="${GATEWAY:-146.164.147.1}"
NETMASK="${NETMASK:-24}"
DOMAIN="${DOMAIN:-lps.ufrj.br}"
ADMIN_USER="${ADMIN_USER:-cluster}"

if [ -z "$NODE_IP" ]; then
    echo "❌ Erro: O endereço IP não foi informado!"
    echo "Uso: sudo bash $0 <ip_address> [hostname]"
    echo "Exemplo: sudo bash $0 146.164.147.201 bancada01"
    exit 1
fi

echo "=============================================================================="
echo "🌐 Configurando Rede e Hostname para: $NODE_HOSTNAME ($NODE_IP/$NETMASK)"
echo "=============================================================================="

# 1. Configurar Hostname
hostnamectl set-hostname "$NODE_HOSTNAME"
if ! grep -q "$NODE_HOSTNAME" /etc/hosts; then
    sed -i "s/127.0.1.1.*/127.0.1.1\t$NODE_HOSTNAME.$DOMAIN\t$NODE_HOSTNAME/" /etc/hosts || true
fi

# 2. Permissão de sudo sem senha para o usuário admin
if id "$ADMIN_USER" &>/dev/null; then
    usermod -aG sudo "$ADMIN_USER"
    echo "$ADMIN_USER ALL=(ALL:ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$ADMIN_USER"
    chmod 440 "/etc/sudoers.d/$ADMIN_USER"
fi

# 3. Detectar interface física de rede principal
if [ -z "${NET_INTERFACE:-}" ]; then
    NET_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth)' | head -n1 || true)
    if [ -z "$NET_INTERFACE" ]; then
        NET_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v -E '^(lo|docker|veth|virbr|wl)' | head -n1)
    fi
fi

if [ -z "$NET_INTERFACE" ]; then
    echo "❌ Erro: Não foi possível detectar a interface de rede física automaticamente."
    exit 1
fi

echo "🔌 Interface de rede detectada: $NET_INTERFACE"

# 4. Gerar arquivo de configuração Netplan moderno (sem gateway4 obsoleto)
NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
cat << EOF > "$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    $NET_INTERFACE:
      dhcp4: false
      addresses:
        - $NODE_IP/$NETMASK
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        search:
          - $DOMAIN
        addresses:
          - 146.164.147.2
          - 8.8.8.8
          - 8.8.4.4
EOF

chmod 600 "$NETPLAN_FILE"

# 5. Aplicar Netplan
echo "🔄 Aplicando configuração Netplan..."
if [ ! -f /.dockerenv ]; then
    netplan apply
else
    netplan generate
fi

echo "✅ Rede configurada com sucesso em: $NETPLAN_FILE"
ip addr show "$NET_INTERFACE" | grep "inet " || true
echo "=============================================================================="
