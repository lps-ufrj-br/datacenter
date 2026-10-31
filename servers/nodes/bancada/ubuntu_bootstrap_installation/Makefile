# ==============================================================================
# LPS / UFRJ - Makefile para Autoinstall / Bootstrap das Bancadas
# ==============================================================================
.DEFAULT_GOAL := help

PYTHON := python3
INVENTORY := inventory.yaml
GENERATOR := generate_autoinstall.py
DIST_DIR := dist

# Variáveis configuráveis via linha de comando
VENTOY_PATH ?= /media/$(USER)/Ventoy
PVE_HOST ?= root@proxmox.lps.ufrj.br
PVE_SNIPPETS_DIR ?= /var/lib/vz/snippets

.PHONY: help
help: ## Exibe este menu de ajuda
	@echo "=============================================================================="
	@echo "🛠️  LPS Bancada - Gerenciamento de Autoinstall & Bootstrap"
	@echo "=============================================================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo "=============================================================================="

.PHONY: generate
generate: ## Gera todos os arquivos de Autoinstall (dist/) a partir de inventory.yaml
	@echo "🚀 Gerando arquivos de configuração de autoinstall..."
	@$(PYTHON) $(GENERATOR)

.PHONY: clean
clean: ## Remove o diretório de arquivos gerados (dist/)
	@echo "🧹 Limpando arquivos gerados em $(DIST_DIR)..."
	@rm -rf $(DIST_DIR)
	@echo "✅ Diretório limpo."

.PHONY: rebuild
rebuild: clean generate ## Limpa e regenera todos os arquivos de autoinstall

.PHONY: list-nodes
list-nodes: ## Lista todas as bancadas configuradas em inventory.yaml
	@echo "📋 Bancadas cadastradas em $(INVENTORY):"
	@awk '/hostname:/ {gsub(/["\r]/, "", $$NF); h=$$NF} /ip:/ {gsub(/["\r]/, "", $$NF); printf "  • %-12s IP: %s\n", h, $$NF}' $(INVENTORY)

.PHONY: copy-to-ventoy
copy-to-ventoy: generate ## Copia os arquivos gerados para o Pendrive Ventoy (Uso: make copy-to-ventoy VENTOY_PATH=/caminho/do/pendrive)
	@if [ ! -d "$(VENTOY_PATH)" ]; then \
		echo "❌ Erro: Caminho do Ventoy não encontrado: $(VENTOY_PATH)"; \
		echo "Informe o caminho correto com: make copy-to-ventoy VENTOY_PATH=/media/seu_usuario/Ventoy"; \
		exit 1; \
	fi
	@echo "📥 Copiando configurações para o Pendrive em: $(VENTOY_PATH)..."
	@mkdir -p "$(VENTOY_PATH)/ventoy/autoinstall"
	@cp -v $(DIST_DIR)/*.yaml "$(VENTOY_PATH)/ventoy/autoinstall/"
	@cp -v $(DIST_DIR)/ventoy.json "$(VENTOY_PATH)/ventoy/ventoy.json"
	@sync
	@echo "✅ Arquivos copiados para o Ventoy com sucesso!"

.PHONY: copy-to-proxmox
copy-to-proxmox: generate ## Envia os snippets gerados para o host Proxmox (Uso: make copy-to-proxmox PVE_HOST=root@ip)
	@echo "📤 Enviando snippets para o Proxmox ($(PVE_HOST):$(PVE_SNIPPETS_DIR))..."
	@ssh $(PVE_HOST) "mkdir -p $(PVE_SNIPPETS_DIR)"
	@scp $(DIST_DIR)/*.yaml $(PVE_HOST):$(PVE_SNIPPETS_DIR)/
	@echo "✅ Snippets enviados com sucesso para o Proxmox!"
