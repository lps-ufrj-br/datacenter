#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 02_install_base.sh
# Base Packages, NFS Mounts, Kerberos, LDAP (Non-Interactive), and SSH Configuration
# ==============================================================================
set -euo pipefail

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

FILES_DIR="$SCRIPT_DIR/files"
if [ ! -d "$FILES_DIR" ] && [ -d "$SCRIPT_DIR/../files" ]; then
    FILES_DIR="$SCRIPT_DIR/../files"
fi

KERBEROS_REALM="${KERBEROS_REALM:-LPS.UFRJ.BR}"
KERBEROS_SERVER="${KERBEROS_SERVER:-auth-server.lps.ufrj.br}"
LDAP_SERVER="${LDAP_SERVER:-ldap://auth-server.lps.ufrj.br}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=lps,dc=ufrj,dc=br}"

echo "=============================================================================="
echo "📦 1. Setting Sysctl and Kernel Panic Constraints"
echo "=============================================================================="
if ! grep -q "vm.panic_on_oom" /etc/sysctl.conf; then
    echo "vm.panic_on_oom = 1" >> /etc/sysctl.conf
fi
if ! grep -q "kernel.panic" /etc/sysctl.conf; then
    echo "kernel.panic = 10" >> /etc/sysctl.conf
fi
sysctl -p || true

echo "=============================================================================="
echo "📁 2. Configuring Network Storage (NFS Mounts)"
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
        echo "  ➕ Added to /etc/fstab: $mount_point"
    fi
}

add_fstab_entry "${NFS_MARKETPLACE} /mnt/market_place nfs rsize=32768,wsize=32768,bg,sync,nolock,_netdev,nofail 0 0" "/mnt/market_place"
add_fstab_entry "${NFS_PROJECTS} /mnt/shared/storage03/projects nfs rsize=32768,wsize=32768,bg,sync,nolock,_netdev,nofail 0 0" "/mnt/shared/storage03/projects"
add_fstab_entry "${NFS_HOMES} /home nfs rsize=32768,wsize=32768,bg,sync,nolock,_netdev,nofail 0 0" "/home"

if [ ! -f /.dockerenv ]; then
    mount -a || true
fi

echo "=============================================================================="
echo "🔐 3. Installing Kerberos (Non-Interactive / Zero Blue Screens)"
echo "=============================================================================="
echo "krb5-config krb5-config/default_realm string $KERBEROS_REALM" | debconf-set-selections
echo "krb5-config krb5-config/kerberos_servers string $KERBEROS_SERVER" | debconf-set-selections
echo "krb5-config krb5-config/admin_server string $KERBEROS_SERVER" | debconf-set-selections

DEBIAN_FRONTEND=noninteractive apt-get install -y krb5-user libpam-krb5

if [ -f "$FILES_DIR/krb5.conf" ]; then
    cp "$FILES_DIR/krb5.conf" /etc/krb5.conf
fi

echo "=============================================================================="
echo "👥 4. Installing and Configuring LDAP Client (nslcd)"
echo "=============================================================================="
echo "nslcd nslcd/ldap-uris string $LDAP_SERVER" | debconf-set-selections
echo "nslcd nslcd/ldap-base string $LDAP_BASE_DN" | debconf-set-selections

# Install modern libnss-ldapd and libpam-ldapd (do NOT install deprecated libnss-ldap)
DEBIAN_FRONTEND=noninteractive apt-get install -y libnss-ldapd libpam-ldapd

if [ -f "$FILES_DIR/nslcd.conf" ]; then
    cp "$FILES_DIR/nslcd.conf" /etc/nslcd.conf
    chmod 600 /etc/nslcd.conf
fi

# Configure nsswitch to authenticate via ldap
for db in passwd group shadow; do
    if ! grep -E "^$db:.*ldap" /etc/nsswitch.conf >/dev/null; then
        sed -i "s/^$db:.*/& ldap/" /etc/nsswitch.conf
    fi
done

# Enable pam_mkhomedir automatically
pam-auth-update --enable mkhomedir

systemctl restart nslcd || true

echo "=============================================================================="
echo "🔑 5. Configuring OpenSSH and LPS Drop-in"
echo "=============================================================================="
DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server

mkdir -p /etc/ssh/sshd_config.d
if [ -f "$FILES_DIR/60-lps-sshd.conf" ]; then
    cp "$FILES_DIR/60-lps-sshd.conf" /etc/ssh/sshd_config.d/60-lps.conf
fi

if [ ! -f /.dockerenv ]; then
    systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || systemctl restart ssh.socket 2>/dev/null || true
fi

echo "=============================================================================="
echo "⏰ 6. Configuring Time Synchronization (systemd-timesyncd)"
echo "=============================================================================="
DEBIAN_FRONTEND=noninteractive apt-get install -y systemd-timesyncd

if [ -f "$FILES_DIR/timesyncd.conf" ]; then
    cp "$FILES_DIR/timesyncd.conf" /etc/systemd/
fi
if [ ! -f /.dockerenv ]; then
    systemctl enable --now systemd-timesyncd 2>/dev/null || true
    timedatectl set-ntp true 2>/dev/null || true
fi

echo "=============================================================================="
echo "📝 7. Configuring SSH Login Audit (PAM logger)"
echo "=============================================================================="
mkdir -p /etc/pam_scripts
chmod 700 /etc/pam_scripts
if [ -f "$FILES_DIR/login-logger.sh" ]; then
    cp "$FILES_DIR/login-logger.sh" /etc/pam_scripts/
    chmod +x /etc/pam_scripts/login-logger.sh
fi

if [ -f /etc/pam.d/sshd ] && ! grep -q "login-logger.sh" /etc/pam.d/sshd; then
    echo "session required pam_exec.so /etc/pam_scripts/login-logger.sh" >> /etc/pam.d/sshd
fi

echo "=============================================================================="
echo "📢 8. Configuring Workstation Welcome Banner (MOTD)"
echo "=============================================================================="
if [ -f "$FILES_DIR/00-main-message" ]; then
    mkdir -p /etc/update-motd.d
    cp "$FILES_DIR/00-main-message" /etc/update-motd.d/00-main-message
    chmod +x /etc/update-motd.d/00-main-message

    # Disable generic Ubuntu MOTD advertisements and default Ubuntu header
    chmod -x /etc/update-motd.d/00-header 2>/dev/null || true
    chmod -x /etc/update-motd.d/10-help-text 2>/dev/null || true
    chmod -x /etc/update-motd.d/50-motd-news 2>/dev/null || true

    # Integrate into /etc/bash.bashrc for all interactive terminal sessions (GNOME Terminal / Tilix / XRDP)
    if ! grep -q "00-main-message" /etc/bash.bashrc 2>/dev/null; then
        cat << 'EOF' >> /etc/bash.bashrc

# LPS / UFRJ - Workstation Welcome Banner
if [ -n "$PS1" ] && [ -x /etc/update-motd.d/00-main-message ]; then
    if [ -z "${SSH_CONNECTION:-}" ] && [ -z "${LPS_MOTD_SHOWN:-}" ]; then
        export LPS_MOTD_SHOWN=1
        /etc/update-motd.d/00-main-message
    fi
fi
EOF
    fi

    # Also keep profile.d for login shells
    cat << 'EOF' > /etc/profile.d/00-lps-welcome.sh
# Show LPS welcome banner in login shell sessions
if [ -n "$PS1" ] && [ -x /etc/update-motd.d/00-main-message ] && [ -z "${LPS_MOTD_SHOWN:-}" ]; then
    export LPS_MOTD_SHOWN=1
    /etc/update-motd.d/00-main-message
fi
EOF
    chmod 644 /etc/profile.d/00-lps-welcome.sh
    echo "  ✅ Welcome banner installed to /etc/update-motd.d/00-main-message, /etc/bash.bashrc and /etc/profile.d/00-lps-welcome.sh"
fi

echo "=============================================================================="
echo "🛠️  9. Installing Essential Diagnostic Tools and XRDP"
echo "=============================================================================="
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    htop sshpass screen rsync vim curl git python3-virtualenv python-is-python3 python3-apt xrdp dconf-cli

systemctl enable xrdp || true

echo "✅ Base installation completed successfully!"
