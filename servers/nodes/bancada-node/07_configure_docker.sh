#!/bin/bash

# Garante que o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Por favor, execute este script como root ou usando sudo."
  exit 1
fi

SERVICE_FILE="/etc/systemd/system/docker-cleanup-reboot.service"

echo "🧹 Configurando a limpeza total do Docker no reboot..."

# 1. Cria o arquivo de serviço do Systemd
cat << 'EOF' > $SERVICE_FILE
[Unit]
Description=Limpeza Total do Docker no Reboot
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
# Deleta containers parados, redes, volumes, imagens e caches de build
ExecStart=/usr/bin/docker system prune -a --volumes -f

[Install]
WantedBy=multi-user.target
EOF

# 2. Ajusta as permissões do arquivo
chmod 644 $SERVICE_FILE

# 3. Recarrega o Systemd para reconhecer o novo serviço
echo "🔄 Recarregando o Systemd..."
systemctl daemon-reload

# 4. Ativa o serviço para iniciar no boot
echo "🚀 Ativando o serviço para o próximo reboot..."
systemctl enable docker-cleanup-reboot.service

echo "--------------------------------------------------------"
echo "✅ Concluído com sucesso!"
echo "O serviço foi criado em: $SERVICE_FILE"
echo "A partir do próximo reboot, todo o lixo do Docker será apagado."
echo "--------------------------------------------------------"