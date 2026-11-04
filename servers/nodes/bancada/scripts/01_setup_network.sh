#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 01_setup_network.sh
# Static Network and Hostname Configuration (Netplan v2 for Ubuntu 22.04 / 24.04 / 26.04)
# ==============================================================================
set -euo pipefail

# Ensure root privileges
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

# Optional CLI parameters: $1 = IP (or reads from config.env)
NODE_IP="${1:-${NODE_IP:-}}"
NODE_HOSTNAME="${2:-${NODE_HOSTNAME:-bancada01}}"
GATEWAY="${GATEWAY:-146.164.147.1}"
NETMASK="${NETMASK:-24}"
DOMAIN="${DOMAIN:-lps.ufrj.br}"
ADMIN_USER="${ADMIN_USER:-cluster}"

if [ -z "$NODE_IP" ]; then
    echo "❌ Error: Node IP address was not provided!"
    echo "Usage: sudo bash $0 <ip_address> [hostname]"
    echo "Example: sudo bash $0 146.164.147.201 bancada01"
    exit 1
fi

echo "=============================================================================="
echo "🌐 Configuring Network and Hostname for: $NODE_HOSTNAME ($NODE_IP/$NETMASK)"
echo "=============================================================================="

# 1. Configure Hostname
if command -v hostnamectl &>/dev/null; then
    hostnamectl set-hostname "$NODE_HOSTNAME" || true
else
    echo "$NODE_HOSTNAME" > /etc/hostname
fi
if ! grep -q "$NODE_HOSTNAME" /etc/hosts 2>/dev/null; then
    # In Docker or mounted /etc/hosts, sed -i may fail if device is busy
    if sed -i "s/127.0.1.1.*/127.0.1.1\t$NODE_HOSTNAME.$DOMAIN\t$NODE_HOSTNAME/" /etc/hosts 2>/dev/null; then
        :
    else
        echo -e "127.0.1.1\t$NODE_HOSTNAME.$DOMAIN\t$NODE_HOSTNAME" >> /etc/hosts 2>/dev/null || true
    fi
fi

# 2. Grant passwordless sudo to admin user
if id "$ADMIN_USER" &>/dev/null; then
    usermod -aG sudo "$ADMIN_USER"
    echo "$ADMIN_USER ALL=(ALL:ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$ADMIN_USER"
    chmod 440 "/etc/sudoers.d/$ADMIN_USER"
fi

# 3. Detect primary physical network interface
if ! command -v ip &>/dev/null; then
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends iproute2 >/dev/null
fi

if [ -z "${NET_INTERFACE:-}" ]; then
    NET_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth)' | head -n1 || true)
    if [ -z "$NET_INTERFACE" ]; then
        NET_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v -E '^(lo|docker|veth|virbr|wl)' | head -n1)
    fi
fi

NET_INTERFACE="${NET_INTERFACE%@*}"

if [ -z "$NET_INTERFACE" ]; then
    echo "❌ Error: Could not automatically detect physical network interface."
    exit 1
fi

echo "🔌 Detected physical network interface: $NET_INTERFACE"

# 4. Generate modern Netplan v2 configuration (without deprecated gateway4)
mkdir -p /etc/netplan
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

# 5. Apply Netplan
echo "🔄 Applying Netplan configuration..."
if command -v netplan &>/dev/null; then
    if [ ! -f /.dockerenv ]; then
        # Ensure systemd-networkd and systemd-resolved are active before applying netplan
        systemctl enable --now systemd-networkd systemd-resolved 2>/dev/null || true
        netplan apply
        systemctl restart systemd-resolved 2>/dev/null || true
        sleep 2
    else
        netplan generate || true
    fi
else
    echo "ℹ️ netplan binary not found in current environment. Configuration file generated."
fi

echo "✅ Network successfully configured at: $NETPLAN_FILE"
if command -v ip &>/dev/null; then
    ip addr show "$NET_INTERFACE" | grep "inet " || true
fi
echo "=============================================================================="
