#!/bin/bash

# Generate a secure random token
TOKEN=$(openssl rand -hex 32)

echo "Generated Token: $TOKEN"

# If .env exists, ask to update it or just show how
if [ -f .env ]; then
    echo ""
    echo "To update your .env file, you can run:"
    echo "sed -i \"s/^K3S_TOKEN=.*/K3S_TOKEN=$TOKEN/\" .env"
    
    read -p "Would you like to update the .env file now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i "s/^K3S_TOKEN=.*/K3S_TOKEN=$TOKEN/" .env
        echo ".env updated successfully."
    fi
fi
