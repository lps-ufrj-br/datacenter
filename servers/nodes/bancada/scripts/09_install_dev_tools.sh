#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 09_install_dev_tools.sh
# Installation of Developer Tools: Visual Studio Code & Google Antigravity
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

echo "=============================================================================="
echo "💻 Installing Workstation Developer Tools (VSCode & Google Antigravity)..."
echo "=============================================================================="

# 1. Install prerequisites
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    wget curl gpg apt-transport-https ca-certificates

# ==============================================================================
# 2. Visual Studio Code (Native APT Package - No Snap / Fully NFS Home Compatible)
# ==============================================================================
echo "📦 1. Installing Visual Studio Code via Microsoft APT repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor --yes -o /etc/apt/keyrings/packages.microsoft.gpg
chmod a+r /etc/apt/keyrings/packages.microsoft.gpg

ARCH="$(dpkg --print-architecture)"
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y code

echo "  ✅ Visual Studio Code successfully installed at $(which code)."

# ==============================================================================
# 3. Google Antigravity (CLI 'agy' & Desktop Integration)
# ==============================================================================
echo "🚀 2. Installing Google Antigravity..."

INSTALL_SUCCESS=false
if curl -fsSL -m 15 https://antigravity.google/cli/install.sh > /tmp/antigravity_installer.sh 2>/dev/null; then
    chmod +x /tmp/antigravity_installer.sh
    if /tmp/antigravity_installer.sh --dir /usr/local/bin; then
        INSTALL_SUCCESS=true
        echo "  ✅ Antigravity CLI ('agy') installed system-wide in /usr/local/bin."
    fi
    rm -f /tmp/antigravity_installer.sh
fi

if [ "$INSTALL_SUCCESS" = false ]; then
    echo "  ⚠️ Official installer network fetch skipped or failed. Setting up CLI launcher fallback..."
    # Fallback placeholder script that guides the user if offline
    cat << 'EOF' > /usr/local/bin/agy
#!/bin/bash
if command -v curl &>/dev/null; then
    echo "📥 Downloading latest Antigravity CLI..."
    curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- --dir /usr/local/bin
    exec /usr/local/bin/agy "$@"
else
    echo "❌ Antigravity CLI is not yet installed. Run 'sudo make dev-tools' with internet access."
    exit 1
fi
EOF
    chmod 755 /usr/local/bin/agy
fi

# Ensure 'antigravity' alias points to 'agy'
ln -sf /usr/local/bin/agy /usr/local/bin/antigravity

# Create Desktop Application Entry for GNOME Dash
cat << 'EOF' > /usr/share/applications/antigravity.desktop
[Desktop Entry]
Name=Antigravity
Comment=Google Antigravity AI-First Development Platform
GenericName=AI Development Environment
Exec=/usr/local/bin/agy
Icon=utilities-terminal
Terminal=true
Type=Application
Categories=Development;IDE;TextEditor;
StartupNotify=true
Keywords=ai;google;agent;antigravity;ide;code;
EOF

chmod 644 /usr/share/applications/antigravity.desktop

echo "=============================================================================="
echo "✅ Developer Tools installation completed successfully!"
echo "   - Visual Studio Code: 'code'"
echo "   - Antigravity CLI:    'agy' (or 'antigravity')"
echo "=============================================================================="
