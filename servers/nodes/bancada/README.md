# Workstation Provisioning System — LPS / UFRJ

This directory manages the automation, provisioning, and configuration of all physical and virtual workstations (**Bancadas**) at the Signal Processing Laboratory (LPS/UFRJ), with native support for **Ubuntu 24.04 LTS and 26.04 LTS**.

To keep the project modular and clean, the infrastructure is split into two independent workflows, each with its own dedicated **Makefile** and documentation:

```
servers/nodes/bancada/
│
├── Makefile                            # Unified master orchestrator
├── README.md                           # Repository overview
│
├── ubuntu_bootstrap_installation/      # [MODE 1: AUTOMATED] Autoinstall / Cloud-Init
│   ├── Makefile                        # Generation and distribution automation (Ventoy / Proxmox)
│   ├── README.md                       # Comprehensive step-by-step tutorial
│   ├── inventory.yaml                  # Central inventory of LPS nodes and network settings
│   ├── generate_autoinstall.py         # Standalone configuration generator script
│   ├── templates/                      # Jinja2 templates (Cloud-Init and Ventoy)
│   └── dist/                           # Generated per-node configurations (bancada01.yaml...)
│
└── ubuntu_manual_installation/         # [MODE 2: MANUAL] Modular post-install scripts
    ├── Makefile                        # Granular or full sequential execution
    ├── README.md                       # Manual scripts guide
    ├── config.env                      # Local node environment variables
    ├── install_all.sh                  # Sequential orchestrator for all scripts
    ├── 01_setup_network.sh             # Modern Netplan and hostname setup
    ├── 02_install_base.sh              # Base packages, NFS, Kerberos, non-interactive LDAP, SSH
    ├── 03_install_singularity.sh       # Official Sylabs SingularityCE installer
    ├── 04_install_docker.sh            # Official Docker CE installer
    ├── 05_install_cuda.sh              # NVIDIA driver and CUDA Toolkit
    ├── 06_custom_login_screen.sh       # GDM customization (hides user list)
    ├── 07_configure_docker.sh          # Docker cleanup on reboot service
    ├── 08_configure_singularity.py     # LDAP fakeroot configuration for UIDs >= 1000
    ├── 09_configure_docker_gpu_toolkit.sh # NVIDIA Container Toolkit
    └── files/                          # Auxiliary configuration files and drop-ins
```

---

## ⚡ Quick Start via Makefile

The Makefile at the root of this directory allows you to trigger operations across both modules:

```bash
# Display the main help menu
make help
```

### 1. Bootstrap Operations (Automated Mode)
```bash
# List all registered nodes and their IPs in the inventory
make bootstrap-list

# Generate all autoinstall files in dist/
make bootstrap-generate

# Copy generated files directly to a Ventoy USB flash drive
make bootstrap-ventoy VENTOY_PATH=/media/$USER/Ventoy

# Upload generated snippets to Proxmox VE
make bootstrap-proxmox PVE_HOST=root@146.164.147.X
```
👉 *For the step-by-step guide on creating a Ventoy USB drive or setting up a VM in Proxmox, see the [Bootstrap README](ubuntu_bootstrap_installation/README.md).*

---

### 2. Manual Installation Operations (Local Node)
When logged in locally or via SSH into a machine with Ubuntu already installed:
```bash
# Run the complete configuration in one pass:
sudo make manual-all

# Or run individual steps:
sudo make manual-network NODE_IP=146.164.147.201 NODE_HOSTNAME=bancada01
sudo make manual-base
sudo make manual-singularity
sudo make manual-docker
sudo make manual-cuda
sudo make manual-gdm
```
👉 *For parameter details and an explanation of each script, see the [Manual Installation README](ubuntu_manual_installation/README.md).*

---

## 🔐 How the Password Works

During the automated installation process (Bootstrap), **no password entry is required at the keyboard**.

The password is securely stored as a **SHA-512 crypt hash** inside [`ubuntu_bootstrap_installation/inventory.yaml`](ubuntu_bootstrap_installation/inventory.yaml).

To set a custom password:
```bash
openssl passwd -6 "your_new_password_here"
```
Copy the generated hash string (e.g., `$6$rounds=4096$...`) and paste it into the `admin_password_hash` field in `inventory.yaml`. Then, run `make bootstrap-generate`.
