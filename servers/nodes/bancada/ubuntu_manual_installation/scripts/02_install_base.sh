#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 02_install_base.sh
# Instalação de Pacotes Base, NFS, Kerberos, LDAP (100% Não-Interativo) e SSH
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

KERBEROS_REALM="${KERBEROS_REALM:-LPS.UFRJ.BR}"
KERBEROS_SERVER="${KERBEROS_SERVER:-auth-server.lps.ufrj.br}"
LDAP_SERVER="${LDAP_SERVER:-ldap://auth-server.lps.ufrj.br}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=lps,dc=ufrj,dc=br}"

echo "=============================================================================="
echo "📦 1. Configurando Sysctl e Restrições de Kernel"
echo "=============================================================================="
if ! grep -q "vm.panic_on_oom" /etc/sysctl.conf; then
    echo "vm.panic_on_oom = 1" >> /etc/sysctl.conf
fi
if ! grep -q "kernel.panic" /etc/sysctl.conf; then
    echo "kernel.panic = 10" >> /etc/sysctl.conf
fi
sysctl -p || true

echo "=============================================================================="
echo "📁 2. Configurando Armazenamento em Rede (NFS)"
echo "=============================================================================="
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-common

mkdir -p /mnt/market_place
mkdir -p /mnt/shared/storage03/projects

add_fstab_entry() {
    local entry="$1"
    local mount_point="$2"
    if ! grep -qs "$mount_point" /etc/fstab; then
        echo "$entry" >> /etc/fstab
        echo "  ➕ Adicionado ao fstab: $mount_point"
    fi
}

add_fstab_entry "${NFS_MARKETPLACE} /mnt/market_place nfs rsize=32768,wsize=32768,bg,sync,nolock,_netdev,nofail 0 0" "/mnt/market_place"
add_fstab_entry "${NFS_PROJECTS} /mnt/shared/storage03/projects nfs rsize=32768,wsize=32768,bg,sync,nolock,_netdev,nofail 0 0" "/mnt/shared/storage03/projects"
add_fstab_entry "${NFS_HOMES} /home nfs rsize=32768,wsize=32768,bg,sync,nolock,_netdev,nofail 0 0" "/home"

mount -a || true

echo "=============================================================================="
echo "🔐 3. Instalando Kerberos (Modo Não-Interativo / Zero Telas Azuis)"
echo "=============================================================================="
echo "krb5-config krb5-config/default_realm string $KERBEROS_REALM" | debconf-set-selections
echo "krb5-config krb5-config/kerberos_servers string $KERBEROS_SERVER" | debconf-set-selections
echo "krb5-config krb5-config/admin_server string $KERBEROS_SERVER" | debconf-set-selections

DEBIAN_FRONTEND=noninteractive apt-get install -y krb5-user libpam-krb5

if [ -f "$SCRIPT_DIR/files/krb5.conf" ]; then
    cp "$SCRIPT_DIR/files/krb5.conf" /etc/krb5.conf
fi

echo "=============================================================================="
echo "👥 4. Instalando e Configurando LDAP (nslcd)"
echo "=============================================================================="
echo "nslcd nslcd/ldap-uris string $LDAP_SERVER" | debconf-set-selections
echo "nslcd nslcd/ldap-base string $LDAP_BASE_DN" | debconf-set-selections

# Instalamos libnss-ldapd e libpam-ldapd (NÃO instalar libnss-ldap obsoleto)
DEBIAN_FRONTEND=noninteractive apt-get install -y libnss-ldapd libpam-ldapd

if [ -f "$SCRIPT_DIR/files/nslcd.conf" ]; then
    cp "$SCRIPT_DIR/files/nslcd.conf" /etc/nslcd.conf
    chmod 600 /etc/nslcd.conf
fi

# Configurar nsswitch para autenticar via ldap
for db in passwd group shadow; do
    if ! grep -E "^$db:.*ldap" /etc/nsswitch.conf >/dev/null; then
        sed -i "s/^$db:.*/& ldap/" /etc/nsswitch.conf
    fi
done

# Ativar pam_mkhomedir automaticamente
pam-auth-update --enable mkhomedir

systemctl restart nslcd || true

echo "=============================================================================="
echo "🔑 5. Configurando SSH e Drop-in LPS"
echo "=============================================================================="
mkdir -p /etc/ssh/sshd_config.d
if [ -f "$SCRIPT_DIR/files/60-lps-sshd.conf" ]; then
    cp "$SCRIPT_DIR/files/60-lps-sshd.conf" /etc/ssh/sshd_config.d/60-lps.conf
fi
systemctl restart ssh || true

echo "=============================================================================="
echo "⏰ 6. Configurando Sincronização de Horário (NTP)"
echo "=============================================================================="
if [ -f "$SCRIPT_DIR/files/timesyncd.conf" ]; then
    cp "$SCRIPT_DIR/files/timesyncd.conf" /etc/systemd/
fi
if [ ! -f /.dockerenv ]; then
    timedatectl set-ntp true || true
fi

echo "=============================================================================="
echo "📝 7. Configurando Auditoria de Logins SSH (PAM)"
echo "=============================================================================="
mkdir -p /etc/pam_scripts
chmod 700 /etc/pam_scripts
if [ -f "$SCRIPT_DIR/files/login-logger.sh" ]; then
    cp "$SCRIPT_DIR/files/login-logger.sh" /etc/pam_scripts/
    chmod +x /etc/pam_scripts/login-logger.sh
fi

if ! grep -q "login-logger.sh" /etc/pam.d/sshd; then
    echo "session required pam_exec.so /etc/pam_scripts/login-logger.sh" >> /etc/pam.d/sshd
fi

echo "=============================================================================="
echo "🛠️ 8. Instalando Ferramentas Adicionais e XRDP"
echo "=============================================================================="
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    htop sshpass screen rsync vim curl git python3-virtualenv python-is-python3 xrdp dconf-cli

systemctl enable xrdp || true

echo "✅ Instalação base concluída com sucesso!"
