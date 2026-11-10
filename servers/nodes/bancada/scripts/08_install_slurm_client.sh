#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 08_install_slurm_client.sh
# Installation and Configuration of SLURM Client (Job Submission / Query Node)
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

SLURM_BUILD_DIR="${SLURM_BUILD_DIR:-/mnt/market_place/slurm_build}"
SLURM_DEB_PATTERN="${SLURM_BUILD_DIR}/slurm-*.deb"

echo "=============================================================================="
echo "⚡ Installing and Configuring SLURM Client (Submitter / Query Node)..."
echo "=============================================================================="

# 1. Verify NFS marketplace mount
if [ ! -d "$SLURM_BUILD_DIR" ]; then
    echo "ℹ️ NFS path '$SLURM_BUILD_DIR' not found. Attempting to mount NFS..."
    mount /mnt/market_place 2>/dev/null || mount -a 2>/dev/null || true
fi

# 2. Install Munge
echo "🔐 1. Installing Munge authentication service..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y libmunge-dev libmunge2 munge

# 3. Synchronize Munge Key from cluster storage
if [ -f "$SLURM_BUILD_DIR/munge.key" ]; then
    cp "$SLURM_BUILD_DIR/munge.key" /etc/munge/munge.key
    chown munge:munge /etc/munge/munge.key
    chmod 400 /etc/munge/munge.key
    echo "  🔑 Cluster munge.key successfully synchronized."
else
    echo "⚠️ Warning: '$SLURM_BUILD_DIR/munge.key' not accessible. Skipping key copy."
    echo "   Ensure NFS /mnt/market_place is mounted to sync the shared cluster key."
fi

if [ ! -f /.dockerenv ]; then
    systemctl enable munge 2>/dev/null || true
    systemctl restart munge 2>/dev/null || true
fi

# 4. Install SLURM binary package
echo "📦 2. Installing SLURM client package..."
SLURM_DEB=$(ls -1t $SLURM_DEB_PATTERN 2>/dev/null | head -n1 || true)

if [ -n "$SLURM_DEB" ] && [ -f "$SLURM_DEB" ]; then
    echo "  Installing: $(basename "$SLURM_DEB")"
    dpkg -i --force-overwrite "$SLURM_DEB" || true
    DEBIAN_FRONTEND=noninteractive apt-get install -f -y
else
    echo "ℹ️ SLURM deb package not found in '$SLURM_BUILD_DIR'."
    echo "   Attempting fallback installation of slurm-client via APT..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y slurm-client || true
fi

# 5. Link SLURM configuration
mkdir -p /etc/slurm
if [ -f "$SLURM_BUILD_DIR/slurm.conf" ]; then
    ln -sf "$SLURM_BUILD_DIR/slurm.conf" /etc/slurm/slurm.conf
    echo "  🔗 Linked /etc/slurm/slurm.conf -> $SLURM_BUILD_DIR/slurm.conf"
fi

# 6. Ensure 'slurm' system user exists
if ! id -u slurm &>/dev/null; then
    useradd -r -s /bin/false slurm 2>/dev/null || true
    echo "👤 Created 'slurm' system user."
fi

# 7. Install LPS monitoring helper 'sjstat'
SJSTAT_SRC=$(find "$SLURM_BUILD_DIR" -maxdepth 4 -name "sjstat" -type f 2>/dev/null | head -n1 || true)
if [ -n "$SJSTAT_SRC" ] && [ -f "$SJSTAT_SRC" ]; then
    cp "$SJSTAT_SRC" /usr/bin/sjstat
    chmod 755 /usr/bin/sjstat
    echo "📊 Installed LPS 'sjstat' monitoring helper to /usr/bin/sjstat."
fi

# 8. Note: slurmd is explicitly NOT enabled
echo "🛡️  Node configured strictly as SLURM client (slurmd executor is NOT active)."
echo "✅ SLURM client installation completed successfully!"
