#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 05_custom_login_screen.sh
# GDM Login Screen Customization (Hide User List & Set Wallpaper in GDM 46+)
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root or using sudo: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================================================="
echo "🖥️  Configuring GDM Login Screen (Dconf)..."
echo "=============================================================================="

# Install dconf-cli if not present
apt-get install -y dconf-cli

FILES_DIR="$SCRIPT_DIR/files"
if [ ! -d "$FILES_DIR" ] && [ -d "$SCRIPT_DIR/../files" ]; then
    FILES_DIR="$SCRIPT_DIR/../files"
fi

# 1. Configure GDM profile
mkdir -p /etc/dconf/profile
if [ -f "$FILES_DIR/gdm" ]; then
    cp "$FILES_DIR/gdm" /etc/dconf/profile/gdm
else
    cat << 'EOF' > /etc/dconf/profile/gdm
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF
fi

# 2. Configure key to disable user list
mkdir -p /etc/dconf/db/gdm.d
if [ -f "$FILES_DIR/00-login-screen" ]; then
    cp "$FILES_DIR/00-login-screen" /etc/dconf/db/gdm.d/00-login-screen
else
    cat << 'EOF' > /etc/dconf/db/gdm.d/00-login-screen
[org/gnome/login-screen]
disable-user-list=true
EOF
fi

# 3. Configure LPS wallpaper customization if file exists
if [ -f "$FILES_DIR/10-customization-screen" ]; then
    cp "$FILES_DIR/10-customization-screen" /etc/dconf/db/gdm.d/10-customization-screen
fi

# 4. Update dconf database
dconf update
echo "✅ GDM login screen successfully updated!"
