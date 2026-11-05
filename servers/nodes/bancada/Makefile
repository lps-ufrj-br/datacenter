# ==============================================================================
# LPS / UFRJ - Makefile for Workstation Installation and Maintenance
# ==============================================================================
.DEFAULT_GOAL := help

SHELL := /bin/bash
SCRIPTS_DIR := scripts
CONFIG_ENV := config.env

# ANSI Color Codes
C_RESET  := \033[0m
C_BOLD   := \033[1m
C_RED    := \033[31m
C_GREEN  := \033[32m
C_YELLOW := \033[33m
C_BLUE   := \033[34m
C_PURPLE := \033[35m
C_CYAN   := \033[36m
C_WHITE  := \033[37m

# Variables (can be overridden via CLI, e.g.: make network NODE_IP=... NODE_HOSTNAME=...)
DEFAULT_IP ?= $(shell awk -F'[:-]' '/NODE_IP=/ {gsub(/["}]/, ""); print $$NF}' $(CONFIG_ENV) 2>/dev/null || echo "146.164.147.201")
DEFAULT_HOSTNAME ?= $(shell awk -F'[:-]' '/NODE_HOSTNAME=/ {gsub(/["}]/, ""); print $$NF}' $(CONFIG_ENV) 2>/dev/null || echo "bancada01")

NODE_IP ?= $(DEFAULT_IP)
NODE_HOSTNAME ?= $(DEFAULT_HOSTNAME)

.PHONY: help
help: ## Display this help menu with instructions and available targets
	@echo "=============================================================================="
	@echo "🛠️  LPS Bancada - Workstation Manual Installation & Maintenance"
	@echo "=============================================================================="
	@echo "🚀 Main Operations:"
	@printf "  $(C_CYAN)%-20s$(C_RESET) %s\n" "install" "Run complete automated installation (steps 1 through 9)"
	@printf "  $(C_CYAN)%-20s$(C_RESET) %s\n" "reboot" "Reboot machine to apply kernel and system service updates"
	@echo ""
	@echo "📋 Step-by-Step Installation (MUST BE RUN IN SEQUENTIAL ORDER):"
	@printf "  $(C_GREEN)%-20s$(C_RESET) %s\n" "[Step 1] network" "Configure static Netplan, hostname, and NOPASSWD sudo"
	@printf "  $(C_GREEN)%-20s$(C_RESET) %s\n" "[Step 2] base" "Install base packages, NFS mounts, Kerberos, LDAP & SSH"
	@printf "  $(C_GREEN)%-20s$(C_RESET) %s\n" "[Step 3] docker" "Install Docker CE, configure log rotation & reboot cleanup"
	@printf "  $(C_GREEN)%-20s$(C_RESET) %s\n" "[Step 4] singularity" "Install SingularityCE (config.env version) & setup fakeroot"
	@printf "  $(C_GREEN)%-20s$(C_RESET) %s\n" "[Step 5] gdm" "Customize GDM login screen (hide users & set LPS wallpaper)"
	@printf "  $(C_YELLOW)%-20s$(C_RESET) %s\n" "[Step 6] cuda" "Install NVIDIA Drivers & CUDA Toolkit (optional if GPU)"
	@printf "  $(C_YELLOW)%-20s$(C_RESET) %s\n" "[Step 7] gpu-toolkit" "Configure NVIDIA Container Toolkit for Docker (optional if GPU)"
	@printf "  $(C_GREEN)%-20s$(C_RESET) %s\n" "[Step 8] slurm-client" "Configure SLURM client & munge key for cluster job submission"
	@printf "  $(C_GREEN)%-20s$(C_RESET) %s\n" "[Step 9] dev-tools" "Install developer tools (Visual Studio Code & Google Antigravity)"
	@echo ""
	@echo "🧪 Docker Validation (Ubuntu 26 amd64):"
	@printf "  $(C_PURPLE)%-20s$(C_RESET) %s\n" "test-all" "Run automated validation matrix of all steps in Ubuntu 26"
	@printf "  $(C_PURPLE)%-20s$(C_RESET) %s\n" "test-step" "Validate a single step in Ubuntu 26 (e.g. make test-step STEP=04)"
	@printf "  $(C_PURPLE)%-20s$(C_RESET) %s\n" "test-shell" "Open interactive bash shell inside clean Ubuntu 26 container"
	@echo ""
	@echo "🔧 Maintenance & Utilities:"
	@printf "  $(C_CYAN)%-20s$(C_RESET) %s\n" "motd" "Update or re-install the workstation welcome banner (MOTD)"
	@printf "  $(C_CYAN)%-20s$(C_RESET) %s\n" "fakeroot" "Re-sync domain accounts from LDAP into Singularity fakeroot"
	@printf "  $(C_CYAN)%-20s$(C_RESET) %s\n" "cleanup" "[ALIAS] Re-run Docker configuration and cleanup service"
	@printf "  $(C_CYAN)%-20s$(C_RESET) %s\n" "apptainer" "[ALIAS] Alias for singularity"
	@printf "  $(C_CYAN)%-20s$(C_RESET) %s\n" "slurm" "[ALIAS] Alias for slurm-client"
	@printf "  $(C_CYAN)%-20s$(C_RESET) %s\n" "vscode" "[ALIAS] Alias for dev-tools"
	@printf "  $(C_CYAN)%-20s$(C_RESET) %s\n" "welcome" "[ALIAS] Alias for motd"
	@printf "  $(C_CYAN)%-20s$(C_RESET) %s\n" "all" "[ALIAS] Alias for install"
	@echo "=============================================================================="
	@echo "⚠️  CRITICAL REQUIREMENT:"
	@echo "   If configuring a node step-by-step, you MUST run targets in sequential"
	@echo "   order (1 -> 2 -> 3 -> 4 -> 5 -> 8 -> 9, plus 6 & 7 if an NVIDIA GPU is present)."
	@echo "   Running steps out of order will cause dependency failures (e.g. LDAP/NFS)."
	@echo "=============================================================================="
	@echo "💡 Examples:"
	@echo "   sudo make install"
	@echo "   sudo make network"
	@echo "   sudo make base"
	@echo "   sudo make slurm-client"
	@echo "   sudo make dev-tools"
	@echo "   make test-all"
	@echo "   make test-step STEP=08"
	@echo "=============================================================================="

.PHONY: check-root
check-root:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo -e "$(C_RED)❌ This target requires root privileges. Please run with sudo: sudo make <target>$(C_RESET)"; \
		exit 1; \
	fi

.PHONY: install
install: check-root ## Run complete automated installation (steps 1 through 9)
	@if [ -t 0 ]; then \
		echo -e "$(C_BOLD)==============================================================================$(C_RESET)"; \
		echo -e "$(C_CYAN)$(C_BOLD)🏢 LPS / UFRJ - Full Bancada Workstation Setup$(C_RESET)"; \
		echo -e "$(C_BOLD)==============================================================================$(C_RESET)"; \
		read -p "Enter Node Hostname [$(NODE_HOSTNAME)]: " input_hostname; \
		TARGET_HOSTNAME=$${input_hostname:-$(NODE_HOSTNAME)}; \
		read -p "Enter Node IP Address [$(NODE_IP)]: " input_ip; \
		TARGET_IP=$${input_ip:-$(NODE_IP)}; \
		echo ""; \
	else \
		TARGET_HOSTNAME="$(NODE_HOSTNAME)"; \
		TARGET_IP="$(NODE_IP)"; \
	fi; \
	echo -e "$(C_BOLD)Target Node:$(C_RESET) $$TARGET_HOSTNAME | $(C_BOLD)IP:$(C_RESET) $$TARGET_IP"; \
	echo "=============================================================================="; \
	echo ""; \
	echo ">> Step 1/9: Network & Hostname Configuration"; \
	./$(SCRIPTS_DIR)/01_setup_network.sh "$$TARGET_IP" "$$TARGET_HOSTNAME"; \
	echo ""; \
	echo ">> Step 2/9: Base Packages, NFS Storage & Authentication"; \
	./$(SCRIPTS_DIR)/02_install_base.sh; \
	echo ""; \
	echo ">> Step 3/9: Docker CE & Services"; \
	./$(SCRIPTS_DIR)/03_install_docker.sh; \
	echo ""; \
	echo ">> Step 4/9: SingularityCE & Domain Fakeroot"; \
	./$(SCRIPTS_DIR)/04_install_singularity.sh; \
	echo ""; \
	echo ">> Step 5/9: GDM Login Screen Customization"; \
	./$(SCRIPTS_DIR)/05_custom_login_screen.sh; \
	echo ""; \
	if lspci 2>/dev/null | grep -i nvidia >/dev/null; then \
		echo ">> Step 6/9: NVIDIA Driver & CUDA Toolkit"; \
		./$(SCRIPTS_DIR)/06_install_cuda.sh; \
		echo ""; \
		echo ">> Step 7/9: NVIDIA Container Toolkit for Docker"; \
		./$(SCRIPTS_DIR)/07_configure_docker_gpu_toolkit.sh; \
		echo ""; \
	else \
		echo "ℹ️  No NVIDIA GPU detected. Skipping Step 6 (CUDA) and Step 7 (GPU Toolkit)."; \
		echo ""; \
	fi; \
	echo ">> Step 8/9: SLURM Client Configuration (Cluster Submitter)"; \
	./$(SCRIPTS_DIR)/08_install_slurm_client.sh; \
	echo ""; \
	echo ">> Step 9/9: Developer Tools (VSCode & Antigravity)"; \
	./$(SCRIPTS_DIR)/09_install_dev_tools.sh; \
	echo ""; \
	echo "=============================================================================="; \
	echo "🎉 Installation completed successfully!"; \
	echo "Workstation $$TARGET_HOSTNAME is configured and ready for use."; \
	echo "To apply all kernel and system updates, please reboot the node:"; \
	echo "  sudo reboot"; \
	echo "=============================================================================="

.PHONY: all
all: install ## [ALIAS] Alias for make install

.PHONY: network
network: check-root ## [Step 1] Configure static Netplan and Hostname
	@if [ -t 0 ]; then \
		echo -e "$(C_BOLD)------------------------------------------------------------------------------$(C_RESET)"; \
		echo -e "$(C_CYAN)$(C_BOLD)🌐 Workstation Network Configuration$(C_RESET)"; \
		echo -e "$(C_BOLD)------------------------------------------------------------------------------$(C_RESET)"; \
		read -p "Enter Node Hostname [$(NODE_HOSTNAME)]: " input_hostname; \
		TARGET_HOSTNAME=$${input_hostname:-$(NODE_HOSTNAME)}; \
		read -p "Enter Node IP Address [$(NODE_IP)]: " input_ip; \
		TARGET_IP=$${input_ip:-$(NODE_IP)}; \
		echo ""; \
	else \
		TARGET_HOSTNAME="$(NODE_HOSTNAME)"; \
		TARGET_IP="$(NODE_IP)"; \
	fi; \
	./$(SCRIPTS_DIR)/01_setup_network.sh "$$TARGET_IP" "$$TARGET_HOSTNAME"

.PHONY: base
base: check-root ## [Step 2] Install base packages, NFS mounts, Kerberos, LDAP & SSH drop-in
	@./$(SCRIPTS_DIR)/02_install_base.sh

.PHONY: docker
docker: check-root ## [Step 3] Install and configure Docker CE (daemon, log rotation & reboot cleanup)
	@./$(SCRIPTS_DIR)/03_install_docker.sh

.PHONY: cleanup
cleanup: docker ## [ALIAS] Re-run Docker configuration and cleanup service registration

.PHONY: singularity
singularity: check-root ## [Step 4] Install SingularityCE official (config.env version) and setup fakeroot
	@./$(SCRIPTS_DIR)/04_install_singularity.sh

.PHONY: apptainer
apptainer: singularity ## [ALIAS] Alias for singularity

.PHONY: gdm
gdm: check-root ## [Step 5] Customize GDM login screen (hide users list & apply LPS wallpaper)
	@./$(SCRIPTS_DIR)/05_custom_login_screen.sh

.PHONY: cuda
cuda: check-root ## [Step 6] Install NVIDIA Drivers and CUDA Toolkit (if GPU present)
	@./$(SCRIPTS_DIR)/06_install_cuda.sh

.PHONY: gpu-toolkit
gpu-toolkit: check-root ## [Step 7] Configure NVIDIA Container Toolkit for Docker (if GPU present)
	@./$(SCRIPTS_DIR)/07_configure_docker_gpu_toolkit.sh

.PHONY: slurm-client
slurm-client: check-root ## [Step 8] Configure SLURM client & munge key for cluster job submission
	@./$(SCRIPTS_DIR)/08_install_slurm_client.sh

.PHONY: slurm
slurm: slurm-client ## [ALIAS] Alias for slurm-client

.PHONY: dev-tools
dev-tools: check-root ## [Step 9] Install developer tools (Visual Studio Code & Google Antigravity)
	@./$(SCRIPTS_DIR)/09_install_dev_tools.sh

.PHONY: vscode
vscode: dev-tools ## [ALIAS] Alias for dev-tools

.PHONY: fakeroot
fakeroot: check-root ## [UTIL] Re-sync fakeroot permissions for domain accounts in LDAP
	@./$(SCRIPTS_DIR)/04_install_singularity.sh --fakeroot-only

.PHONY: motd welcome
motd: check-root ## [UTIL] Update or re-install the workstation welcome banner (MOTD)
	@mkdir -p /etc/update-motd.d /etc/profile.d
	@if [ -f files/00-main-message ]; then \
		cp files/00-main-message /etc/update-motd.d/00-main-message; \
		chmod +x /etc/update-motd.d/00-main-message; \
		chmod -x /etc/update-motd.d/00-header 2>/dev/null || true; \
		chmod -x /etc/update-motd.d/10-help-text 2>/dev/null || true; \
		chmod -x /etc/update-motd.d/50-motd-news 2>/dev/null || true; \
		if ! grep -q "00-main-message" /etc/bash.bashrc 2>/dev/null; then \
			echo "" >> /etc/bash.bashrc; \
			echo "# LPS / UFRJ - Workstation Welcome Banner" >> /etc/bash.bashrc; \
			echo 'if [ -n "$$PS1" ] && [ -x /etc/update-motd.d/00-main-message ]; then' >> /etc/bash.bashrc; \
			echo '    if [ -z "$${SSH_CONNECTION:-}" ] && [ -z "$${LPS_MOTD_SHOWN:-}" ]; then' >> /etc/bash.bashrc; \
			echo '        export LPS_MOTD_SHOWN=1' >> /etc/bash.bashrc; \
			echo '        /etc/update-motd.d/00-main-message' >> /etc/bash.bashrc; \
			echo '    fi' >> /etc/bash.bashrc; \
			echo 'fi' >> /etc/bash.bashrc; \
		fi; \
		echo '# Show LPS welcome banner in login shell sessions' > /etc/profile.d/00-lps-welcome.sh; \
		echo 'if [ -n "$$PS1" ] && [ -x /etc/update-motd.d/00-main-message ] && [ -z "$${LPS_MOTD_SHOWN:-}" ]; then' >> /etc/profile.d/00-lps-welcome.sh; \
		echo '    export LPS_MOTD_SHOWN=1' >> /etc/profile.d/00-lps-welcome.sh; \
		echo '    /etc/update-motd.d/00-main-message' >> /etc/profile.d/00-lps-welcome.sh; \
		echo 'fi' >> /etc/profile.d/00-lps-welcome.sh; \
		chmod 644 /etc/profile.d/00-lps-welcome.sh; \
		echo "✅ MOTD banner updated successfully! Previewing banner:"; \
		echo ""; \
		/etc/update-motd.d/00-main-message; \
	else \
		echo "❌ files/00-main-message not found."; \
		exit 1; \
	fi

welcome: motd ## [ALIAS] Alias for motd

.PHONY: reboot
reboot: check-root ## Reboot the node to apply kernel and service updates
	@echo "🔄 Rebooting machine..."
	@reboot

# ------------------------------------------------------------------------------
# Docker Validation Targets (Ubuntu 26 amd64)
# ------------------------------------------------------------------------------
.PHONY: test-shell test-step test-all
test-shell: ## Launch interactive test shell in clean Ubuntu 26 container
	@./$(SCRIPTS_DIR)/test_in_docker.sh shell

test-step: ## Validate a single step in Ubuntu 26 container (e.g. make test-step STEP=04)
	@./$(SCRIPTS_DIR)/test_in_docker.sh $(or $(STEP),all)

test-all: ## Run the full validation matrix in an Ubuntu 26 container
	@./$(SCRIPTS_DIR)/test_in_docker.sh all
