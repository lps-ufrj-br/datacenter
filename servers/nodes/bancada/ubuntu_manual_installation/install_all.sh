#!/bin/bash
# ==============================================================================
# LPS / UFRJ - install_all.sh
# Orquestrador Sequencial para Configuração de Nós de Bancada
# ==============================================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "❌ Execute este script como root ou usando sudo: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCEd[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
fi

print_header() {
    echo ""
    echo "=============================================================================="
    echo "🚀 $1"
    echo "=============================================================================="
}

run_step() {
    local step_num="$1"
    local script_name="$2"
    local description="$3"

    print_header "Etapa $step_num: $description ($script_name)"
    if [ -f "$SCRIPT_DIR/$script_name" ]; then
        bash "$SCRIPT_DIR/$script_name"
    else
        echo "⚠️  Script não encontrado: $script_name (pulando)"
    fi
}

echo "=============================================================================="
echo "🏢 LPS / UFRJ - Instalação e Configuração Completa do Nó de Bancada"
echo "Host: ${NODE_HOSTNAME:-bancada01} | IP: ${NODE_IP:-146.164.147.201}"
echo "=============================================================================="

# Etapa 1: Rede e Hostname
run_step "1" "01_setup_network.sh" "Configuração de Rede Estática e Hostname"

# Etapa 2: Pacotes Base, NFS, Kerberos, LDAP e SSH
run_step "2" "02_install_base.sh" "Pacotes Base, Storage NFS, Autenticação e SSH"

# Etapa 3: Singularity
run_step "3" "03_install_singularity.sh" "Instalação do SingularityCE e Fakeroot"

# Etapa 4: Docker CE
run_step "4" "04_install_docker.sh" "Instalação do Docker Community Edition"

# Etapa 5: Limpeza do Docker no Boot
run_step "5" "07_configure_docker.sh" "Serviço de Limpeza Automática do Docker"

# Etapa 6: Driver NVIDIA e CUDA Toolkit (opcional se houver GPU)
if lspci 2>/dev/null | grep -i nvidia >/dev/null; then
    run_step "6" "05_install_cuda.sh" "Instalação de Drivers NVIDIA e CUDA Toolkit"
    run_step "7" "09_configure_docker_gpu_toolkit.sh" "Configuração do NVIDIA Container Toolkit"
else
    echo "ℹ️ Nenhuma GPU NVIDIA detectada. Pulando etapas de CUDA e GPU Container Toolkit."
fi

# Etapa 8: Customização do GDM
run_step "8" "06_custom_login_screen.sh" "Configuração da Tela de Login do GDM"

print_header "🎉 Configuração Concluída com Sucesso!"
echo "O nó ${NODE_HOSTNAME:-bancada01} está configurado e pronto para uso."
echo "Para aplicar todas as alterações de kernel e serviços, recomenda-se reiniciar o nó:"
echo "  sudo reboot"
echo "=============================================================================="
