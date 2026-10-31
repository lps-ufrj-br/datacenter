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

# Run all configuration steps from start to finish
sudo make all

# Or run a specific step:
sudo make network NODE_IP=146.164.147.201 NODE_HOSTNAME=bancada01
sudo make base
sudo make singularity
sudo make docker
sudo make cuda
sudo make gpu-toolkit
sudo make gdm
sudo make cleanup
sudo make fakeroot
```

---

## ⚙️ Local Configuration (`config.env`)

The [`config.env`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_manual_installation/config.env) file sets parameters for the local node where scripts are running:

```bash
NODE_HOSTNAME="bancada01"
NODE_IP="146.164.147.201"
NETMASK="24"
GATEWAY="146.164.147.1"
DOMAIN="lps.ufrj.br"
ADMIN_USER="cluster"
```

> **Tip:** You can edit variables in `config.env` before running `sudo make all`, or pass them directly on the command line to make (e.g., `sudo make network NODE_IP=146.164.147.205 NODE_HOSTNAME=bancada05`).

---

## 📋 Script Catalog

| Script / Makefile Target | Description |
| :--- | :--- |
| `make all` / [`install_all.sh`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_manual_installation/install_all.sh) | Master orchestrator. Runs all steps in sequence, checking dependencies and handling errors. |
| `make network` / [`01_setup_network.sh`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_manual_installation/01_setup_network.sh) | Detects the active physical interface (e.g., `eno1`), generates `/etc/netplan/01-netcfg.yaml`, sets hostname, and configures sudo NOPASSWD for `cluster`. |
| `make base` / [`02_install_base.sh`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_manual_installation/02_install_base.sh) | Sets kernel panic constraints (`panic_on_oom`), mounts NFS shares (`/mnt/market_place`, `/mnt/shared/...`, `/home`), preseeds debconf, and installs Kerberos/LDAP silently, activating `pam_mkhomedir` and SSH drop-in. |
| `make singularity` / [`03_install_singularity.sh`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_manual_installation/03_install_singularity.sh) | Installs official Sylabs SingularityCE via distribution `.deb` package and configures fakeroot permissions. |
| `make docker` / [`04_install_docker.sh`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_manual_installation/04_install_docker.sh) | Adds official Docker Inc. repository, installs Docker CE, and adds the `cluster` user to the `docker` group. |
| `make cleanup` / [`07_configure_docker.sh`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_manual_installation/07_configure_docker.sh) | Creates the systemd unit `docker-cleanup-reboot.service` to clean unused images and volumes on every node reboot. |
| `make cuda` / [`05_install_cuda.sh`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_manual_installation/05_install_cuda.sh) | Checks for NVIDIA GPU via `lspci`, adds the official `cuda-keyring`, installs driver and toolkit, and sets up `/etc/profile.d/cuda.sh`. |
| `make gpu-toolkit` / [`09_configure_docker_gpu_toolkit.sh`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_manual_installation/09_configure_docker_gpu_toolkit.sh) | Installs NVIDIA Container Toolkit runtime and configures Docker for `--gpus all` acceleration. |
| `make gdm` / [`06_custom_login_screen.sh`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_manual_installation/06_custom_login_screen.sh) | Hides the user list on the GDM login screen via dconf database (`disable-user-list=true`). |
| `make fakeroot` / [`08_configure_singularity.py`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_manual_installation/08_configure_singularity.py) | Reads LDAP user database via `getent passwd` and adds fakeroot permissions for all users with UID $\ge 1000$. |
