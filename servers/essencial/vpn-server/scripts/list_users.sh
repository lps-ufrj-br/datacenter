#!/bin/bash

# Get the last part of the current working directory
current_dir="${PWD##*/}"
# Check if the current directory is named 'scripts'
if [ "$current_dir" != "scripts" ]; then
    echo "Error: This script must be run from the 'scripts' directory."
    exit 1
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "List all OpenVPN client certificates and their statuses (VALID, REVOKED, EXPIRED)."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message and exit"
    echo ""
    echo "Example:"
    echo "  ./list_users.sh"
    exit 0
fi

docker-compose -f ../files/docker-compose.yaml run --rm openvpn ovpn_listclients "$@"
