#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 04_install_singularity.sh
# Full Installation and Configuration of SingularityCE (Sylabs Official) on Ubuntu
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

SINGULARITY_VERSION="${SINGULARITY_VERSION:-4.6.0}"
FAKEROOT_HELPER="/usr/local/bin/configure_singularity_fakeroot.py"

# Write the standalone fakeroot helper to the system (single source of truth)
install_fakeroot_helper() {
    cat << 'EOF' > "$FAKEROOT_HELPER"
#!/usr/bin/env python3
import sys, subprocess, shutil

binary = shutil.which("singularity") or shutil.which("apptainer")
if not binary:
    print("⚠️ Neither singularity nor apptainer found in PATH.", file=sys.stderr)
    sys.exit(0)

try:
    res = subprocess.run(["getent", "passwd"], capture_output=True, text=True, check=True)
    lines = res.stdout.splitlines()
except Exception as e:
    print(f"❌ Error querying domain users: {e}", file=sys.stderr)
    sys.exit(1)

configured = 0
for line in lines:
    parts = line.split(":")
    if len(parts) < 3:
        continue
    username = parts[0]
    try:
        uid = int(parts[2])
    except ValueError:
        continue
    if 1000 <= uid < 60000 and username != "nobody":
        cmd = [binary, "config", "fakeroot", "--add", username]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode == 0:
            print(f"  ✅ Fakeroot added for: {username} (UID {uid})")
            configured += 1

print(f"✨ Completed: {configured} domain accounts configured for fakeroot in {binary.split('/')[-1]}.")
EOF
    chmod 755 "$FAKEROOT_HELPER"
}

run_fakeroot_sync() {
    echo "=============================================================================="
    echo "⚙️  Configuring fakeroot permissions for LDAP domain users..."
    echo "=============================================================================="
    if [ ! -f "$FAKEROOT_HELPER" ]; then
        install_fakeroot_helper
    fi
    "$FAKEROOT_HELPER"
}

# If invoked with --fakeroot-only flag (e.g. via `make fakeroot`)
if [ "${1:-}" = "--fakeroot-only" ]; then
    run_fakeroot_sync
    exit 0
fi

echo "=============================================================================="
echo "📦 Installing SingularityCE v${SINGULARITY_VERSION}..."
echo "=============================================================================="

# 1. Install build and container dependencies
apt-get update

# Detect FUSE library version available (Ubuntu 26+ uses libfuse3-4, 24.04 uses libfuse3-3)
FUSE_PKG="libfuse3-3"
if apt-cache show libfuse3-4 &>/dev/null; then
    FUSE_PKG="libfuse3-4"
fi

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential libseccomp-dev pkg-config squashfs-tools \
    cryptsetup uidmap wget curl ca-certificates fuse3 crun fuse2fs \
    "$FUSE_PKG"

# Ensure local AppArmor config path exists (prevents Sylabs postinst warnings on minimal images)
mkdir -p /etc/apparmor.d/local

# 2. Detect Ubuntu codename (noble for 24.04, stonking for 26.10, jammy for 22.04)
CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME:-noble}")
DEB_NAME="singularity-ce_${SINGULARITY_VERSION}-${CODENAME}_amd64.deb"
DOWNLOAD_URL="https://github.com/sylabs/singularity/releases/download/v${SINGULARITY_VERSION}/${DEB_NAME}"

echo "📥 Downloading official Sylabs package for $CODENAME (v${SINGULARITY_VERSION})..."
if ! wget -q -O "/tmp/$DEB_NAME" "$DOWNLOAD_URL"; then
    echo "⚠️ Specific package for '$CODENAME' not found. Falling back to 'noble' package..."
    DEB_NAME="singularity-ce_${SINGULARITY_VERSION}-noble_amd64.deb"
    DOWNLOAD_URL="https://github.com/sylabs/singularity/releases/download/v${SINGULARITY_VERSION}/${DEB_NAME}"
    wget -q -O "/tmp/$DEB_NAME" "$DOWNLOAD_URL"
fi

# 3. Install official .deb package with dependency resolution
echo "📦 Installing /tmp/$DEB_NAME..."
if [ "$FUSE_PKG" = "libfuse3-4" ]; then
    # In Ubuntu 26+, libfuse3-4 supersedes libfuse3-3.
    # Provide a virtual transitional package for libfuse3-3 so APT dependencies remain 100% clean
    if ! dpkg -s libfuse3-3 2>/dev/null | grep -q "Status: install ok installed"; then
        echo "ℹ️ Creating compatibility transitional package for libfuse3-3 on Ubuntu 26+..."
        DUMMY_DIR=$(mktemp -d)
        mkdir -p "$DUMMY_DIR/DEBIAN"
        cat << 'EOF' > "$DUMMY_DIR/DEBIAN/control"
Package: libfuse3-3
Version: 3.16.2-99ubuntu1
Architecture: all
Maintainer: LPS UFRJ <datacenter@lps.ufrj.br>
Depends: libfuse3-4
Description: Compatibility dummy package providing libfuse3-3 via libfuse3-4
EOF
        dpkg-deb -b "$DUMMY_DIR" "/tmp/libfuse3-3_dummy.deb" >/dev/null
        dpkg -i "/tmp/libfuse3-3_dummy.deb" >/dev/null
        rm -rf "$DUMMY_DIR" "/tmp/libfuse3-3_dummy.deb"
    fi
fi

apt-get install -y "/tmp/$DEB_NAME"
rm -f "/tmp/$DEB_NAME"

echo "ℹ️ Singularity successfully installed:"
singularity --version

# 4. Install fakeroot helper to system and run initial sync
install_fakeroot_helper
run_fakeroot_sync

echo "✅ Singularity successfully installed and configured!"
