#!/bin/bash
# ==============================================================================
# LPS / UFRJ - 07_configure_docker.sh
# Serviço Systemd de Limpeza Automática do Docker no Reboot
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root ou usando sudo: sudo bash $0"
    exit 1
fi

SERVICE_FILE="/etc/systemd/system/docker-cleanup-reboot.service"

echo "🧹 Configurando a limpeza total do Docker no reboot..."

cat << 'EOF' > "$SERVICE_FILE"
[Unit]
Description=Limpeza Total do Docker no Reboot
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker system prune -a --volumes -f

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$SERVICE_FILE"

if [ ! -f /.dockerenv ]; then
    systemctl daemon-reload
    systemctl enable docker-cleanup-reboot.service
fi

echo "✅ Serviço criado e habilitado: $SERVICE_FILE"