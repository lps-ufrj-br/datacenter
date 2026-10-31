# ==============================================================================
# LPS / UFRJ - Makefile Principal para Bancadas
# Orquestra os modos: Bootstrap (Automático) e Manual (Reconfiguração)
# ==============================================================================
.DEFAULT_GOAL := help

BOOTSTRAP_DIR := ubuntu_bootstrap_installation
MANUAL_DIR := ubuntu_manual_installation

VENTOY_PATH ?= /media/$(USER)/Ventoy
PVE_HOST ?= root@proxmox.lps.ufrj.br
NODE_IP ?=
NODE_HOSTNAME ?=

.PHONY: help
help: ## Exibe este menu com as opções de Bootstrap e Instalação Manual
	@echo "=============================================================================="
	@echo "🏢 LPS / UFRJ - Sistema de Gerenciamento de Bancadas"
	@echo "=============================================================================="
	@echo "Modo 1: Autoinstall / Bootstrap (Novas máquinas via Pendrive ou Proxmox):"
	@grep -E '^[a-zA-Z_-]+:.*?## \[BOOTSTRAP\] .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## \\[BOOTSTRAP\\] "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Modo 2: Instalação / Reconfiguração Manual (Máquinas já existentes):"
	@grep -E '^[a-zA-Z_-]+:.*?## \[MANUAL\] .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## \\[MANUAL\\] "}; {printf "  \033[33m%-22s\033[0m %s\n", $$1, $$2}'
	@echo "=============================================================================="
	@echo "💡 Para mais detalhes, consulte:"
	@echo "   • ubuntu_bootstrap_installation/README.md"
	@echo "   • ubuntu_manual_installation/README.md"
	@echo "=============================================================================="

# ------------------------------------------------------------------------------
# Comandos de Bootstrap / Autoinstall
# ------------------------------------------------------------------------------
.PHONY: bootstrap-generate
bootstrap-generate: ## [BOOTSTRAP] Gera todos os arquivos Cloud-Init/Ventoy em dist/
	@$(MAKE) -C $(BOOTSTRAP_DIR) generate

.PHONY: bootstrap-list
bootstrap-list: ## [BOOTSTRAP] Lista as bancadas cadastradas e seus IPs
	@$(MAKE) -C $(BOOTSTRAP_DIR) list-nodes

.PHONY: bootstrap-ventoy
bootstrap-ventoy: ## [BOOTSTRAP] Copia configurações geradas para o Pendrive Ventoy (Uso: make bootstrap-ventoy VENTOY_PATH=...)
	@$(MAKE) -C $(BOOTSTRAP_DIR) copy-to-ventoy VENTOY_PATH=$(VENTOY_PATH)

.PHONY: bootstrap-proxmox
bootstrap-proxmox: ## [BOOTSTRAP] Envia os snippets gerados para o Proxmox (Uso: make bootstrap-proxmox PVE_HOST=...)
	@$(MAKE) -C $(BOOTSTRAP_DIR) copy-to-proxmox PVE_HOST=$(PVE_HOST)

.PHONY: bootstrap-clean
bootstrap-clean: ## [BOOTSTRAP] Remove arquivos gerados da pasta dist/
	@$(MAKE) -C $(BOOTSTRAP_DIR) clean

# ------------------------------------------------------------------------------
# Comandos de Instalação Manual
# ------------------------------------------------------------------------------
.PHONY: manual-all
manual-all: ## [MANUAL] Executa a instalação completa sequencial no nó local
	@$(MAKE) -C $(MANUAL_DIR) all

.PHONY: manual-network
manual-network: ## [MANUAL] Configura apenas Rede e Hostname (Uso: make manual-network NODE_IP=... NODE_HOSTNAME=...)
	@$(MAKE) -C $(MANUAL_DIR) network NODE_IP=$(NODE_IP) NODE_HOSTNAME=$(NODE_HOSTNAME)

.PHONY: manual-base
manual-base: ## [MANUAL] Instala pacotes base, NFS, Kerberos, LDAP e SSH drop-in
	@$(MAKE) -C $(MANUAL_DIR) base

.PHONY: manual-docker
manual-docker: ## [MANUAL] Instala o Docker CE e permissões de grupo
	@$(MAKE) -C $(MANUAL_DIR) docker

.PHONY: manual-singularity
manual-singularity: ## [MANUAL] Instala o SingularityCE oficial
	@$(MAKE) -C $(MANUAL_DIR) singularity

.PHONY: manual-apptainer
manual-apptainer: manual-singularity ## [MANUAL] Alias para manual-singularity

.PHONY: manual-cuda
manual-cuda: ## [MANUAL] Instala drivers NVIDIA e CUDA Toolkit
	@$(MAKE) -C $(MANUAL_DIR) cuda

.PHONY: manual-gdm
manual-gdm: ## [MANUAL] Configura tela de login do GDM
	@$(MAKE) -C $(MANUAL_DIR) gdm
