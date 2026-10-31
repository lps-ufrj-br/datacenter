# ==============================================================================
# LPS / UFRJ - Makefile para Instalação e Reconfiguração Manual das Bancadas
# ==============================================================================
.DEFAULT_GOAL := help

SHELL := /bin/bash
SUDO := $(shell which sudo 2>/dev/null)

# Variáveis padrão (podem ser sobrescritas via linha de comando ou config.env)
NODE_IP ?=
NODE_HOSTNAME ?=

.PHONY: help
help: ## Exibe este menu de ajuda com todos os alvos disponíveis
	@echo "=============================================================================="
	@echo "🛠️  LPS Bancada - Scripts de Instalação e Reconfiguração Manual"
	@echo "=============================================================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo "=============================================================================="
	@echo "💡 Exemplos de uso:"
	@echo "   sudo make all"
	@echo "   sudo make network NODE_IP=146.164.147.201 NODE_HOSTNAME=bancada01"
	@echo "   sudo make base"
	@echo "   sudo make docker"
	@echo "=============================================================================="

.PHONY: check-root
check-root:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "❌ Este alvo requer privilégios de root. Execute com sudo: sudo make <alvo>"; \
		exit 1; \
	fi

.PHONY: all
all: check-root ## Executa todas as etapas de configuração sequencialmente
	@./install_all.sh

.PHONY: network
network: check-root ## Configura Netplan estático e Hostname (Uso: make network NODE_IP=... NODE_HOSTNAME=...)
	@./01_setup_network.sh "$(NODE_IP)" "$(NODE_HOSTNAME)"

.PHONY: base
base: check-root ## Instala pacotes base, NFS, Kerberos, LDAP e SSH drop-in
	@./02_install_base.sh

.PHONY: singularity
singularity: check-root ## Instala SingularityCE oficial e configura fakeroot
	@./03_install_singularity.sh

.PHONY: apptainer
apptainer: singularity ## Alias para singularity

.PHONY: docker
docker: check-root ## Instala o Docker CE e adiciona o usuário cluster ao grupo
	@./04_install_docker.sh

.PHONY: cleanup
cleanup: check-root ## Instala o serviço systemd de limpeza do Docker no reboot
	@./07_configure_docker.sh

.PHONY: cuda
cuda: check-root ## Instala Drivers NVIDIA e CUDA Toolkit (se houver GPU)
	@./05_install_cuda.sh

.PHONY: gpu-toolkit
gpu-toolkit: check-root ## Configura o NVIDIA Container Toolkit para Docker
	@./09_configure_docker_gpu_toolkit.sh

.PHONY: gdm
gdm: check-root ## Customiza tela de login do GDM (oculta lista de usuários)
	@./06_custom_login_screen.sh

.PHONY: fakeroot
fakeroot: check-root ## Atualiza permissões de fakeroot para contas de domínio LDAP
	@./08_configure_singularity.py

.PHONY: reboot
reboot: check-root ## Reinicia o nó para aplicar mudanças de kernel e serviços
	@echo "🔄 Reiniciando a máquina..."
	@reboot
