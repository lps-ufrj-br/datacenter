# Manual Installation and Reconfiguration Guide (Modular Scripts)

This directory contains scripts and a Makefile for **installing, updating, or reconfiguring active workstations** (physical PCs or VMs) at LPS/UFRJ running **Ubuntu 22.04, 24.04, and 26.04**.

Unlike legacy versions, all scripts have been modernized for:
* Non-interactive execution (zero blue debconf dialogs for Kerberos and LDAP);
* Modern Netplan standard syntax (`routes: - to: default, via: ...`);
* Official Sylabs SingularityCE installation with automated fakeroot for LDAP domain users;
* Resilient NFS mounts with boot hang protection (`_netdev,nofail`).

---

## 🛠️ Makefile Commands

You can run the entire process sequentially or execute specific stages individually:

```bash
# Display all available targets and options
make help

# Run all configuration steps from start to finish (prompts for hostname/IP with config.env defaults)
sudo make install

# Or run a specific step:
sudo make network
sudo make base
sudo make singularity
sudo make docker
sudo make cuda
sudo make gpu-toolkit
sudo make gdm
sudo make slurm-client
sudo make dev-tools
sudo make cleanup
sudo make fakeroot

# 🧪 Docker Validation (Ubuntu 26 amd64 container simulation)
make test-all             # Run automated validation matrix across all steps
make test-step STEP=08    # Test a specific step (e.g. SLURM client)
make test-shell           # Open interactive bash shell inside Ubuntu 26 container
```

---

## ⚙️ Local Configuration (`config.env`)

The [`config.env`](file:///home/cluster/datacenter/servers/nodes/bancada/config.env) file sets default parameters for the local node:

```bash
NODE_HOSTNAME="bancada01"
NODE_IP="146.164.147.201"
NETMASK="24"
GATEWAY="146.164.147.1"
DOMAIN="lps.ufrj.br"
ADMIN_USER="cluster"
SINGULARITY_VERSION="4.6.0"
```

> **Tip:** When running `sudo make install` or `sudo make network`, you will be prompted for hostname and IP with these defaults pre-filled (press Enter to accept).

---

## 📋 Script Catalog

| Script / Makefile Target | Description |
| :--- | :--- |
| `make install` | Master orchestrator. Prompts for node info and runs all steps (1 through 9) in sequence, handling GPU detection. |
| `make network` / [`scripts/01_setup_network.sh`](scripts/01_setup_network.sh) | Detects the active physical interface (e.g., `eno1`), generates `/etc/netplan/01-netcfg.yaml`, sets hostname, and configures sudo NOPASSWD for `cluster`. |
| `make base` / [`scripts/02_install_base.sh`](scripts/02_install_base.sh) | Sets kernel panic constraints (`panic_on_oom`), mounts NFS shares (`/mnt/market_place`, `/mnt/shared/...`, `/home`), preseeds debconf, and installs Kerberos/LDAP silently, activating `pam_mkhomedir` and SSH drop-in. |
| `make docker` / [`scripts/03_install_docker.sh`](scripts/03_install_docker.sh) | Adds official Docker Inc. repository, installs Docker CE, configures daemon log rotation (`50m`), adds user to group, and installs reboot cleanup service. |
| `make singularity` / [`scripts/04_install_singularity.sh`](scripts/04_install_singularity.sh) | Installs official Sylabs SingularityCE (version from `config.env`) via `.deb` package and configures fakeroot permissions for LDAP users. |
| `make gdm` / [`scripts/05_custom_login_screen.sh`](scripts/05_custom_login_screen.sh) | Hides the user list on the GDM login screen via dconf database (`disable-user-list=true`) and applies LPS custom wallpaper. |
| `make cuda` / [`scripts/06_install_cuda.sh`](scripts/06_install_cuda.sh) | *(Optional if GPU)* Checks for NVIDIA GPU via `lspci`, adds `cuda-keyring`, installs driver and toolkit, and sets up `/etc/profile.d/cuda.sh`. |
| `make gpu-toolkit` / [`scripts/07_configure_docker_gpu_toolkit.sh`](scripts/07_configure_docker_gpu_toolkit.sh) | *(Optional if GPU)* Installs NVIDIA Container Toolkit runtime and configures Docker for `--gpus all` acceleration. |
| `make slurm-client` / [`scripts/08_install_slurm_client.sh`](scripts/08_install_slurm_client.sh) | Configures the workstation as a SLURM cluster submitter node (syncs `munge.key`, installs SLURM client tools & `sjstat`, without running `slurmd`). |
| `make dev-tools` / [`scripts/09_install_dev_tools.sh`](scripts/09_install_dev_tools.sh) | Installs Visual Studio Code (via official Microsoft APT repository) and Google Antigravity (CLI `agy` + desktop application). |
| `make fakeroot` | *(Utility)* Re-syncs fakeroot permissions for domain users in Singularity without reinstalling. |
| `make cleanup` | *(Alias)* Re-runs Docker configuration and cleanup service registration. |
