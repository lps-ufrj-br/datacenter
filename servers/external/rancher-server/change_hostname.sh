#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

NEW_HOSTNAME=$1

if [ -z "$NEW_HOSTNAME" ]; then
    echo "Usage: $0 <new-hostname>"
    exit 1
fi

OLD_HOSTNAME=$(hostname)

echo "Changing hostname from $OLD_HOSTNAME to $NEW_HOSTNAME..."

# 1. Update /etc/hostname
echo "$NEW_HOSTNAME" > /etc/hostname

# 2. Set hostname for current session
hostname "$NEW_HOSTNAME"

# 3. Update /etc/hosts
# Replacing any occurrence of the old hostname with the new one
sed -i "s/\b$OLD_HOSTNAME\b/$NEW_HOSTNAME/g" /etc/hosts

# 4. Use hostnamectl if available for persistent system change
if command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl set-hostname "$NEW_HOSTNAME"
fi

echo "Hostname changed successfully to $NEW_HOSTNAME."
echo "You may need to restart your shell session or reboot for all changes to take effect."
