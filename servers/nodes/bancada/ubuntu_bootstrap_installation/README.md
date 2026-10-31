# Automated Installation Guide (Bootstrap / Autoinstall / Cloud-Init)

This folder contains the **Autoinstall and Cloud-Init** ecosystem for **100% unattended (Zero-Touch)** provisioning of LPS/UFRJ workstations on **Ubuntu 24.04 LTS and 26.04 LTS**.

The entire laboratory stack is injected and installed **directly during the operating system installation phase**, both on **physical hardware (via Ventoy multiboot USB)** and on **virtual machines in Proxmox VE**:
* 📦 **Official SingularityCE (Sylabs):** Downloaded and installed directly from the official v4.6.0 `.deb` package.
* 👤 **Automated Fakeroot for Singularity:** The oneshot systemd service `lps-fakeroot-init.service` executes on first boot (once network and LDAP are up) and registers all domain users (UID $\ge 1000$) in fakeroot via `singularity config fakeroot --add`.
* 🐳 **Complete Docker Stack:** Official Docker CE installation, `cluster` user added to the `docker` group, `/etc/docker/daemon.json` with log rotation, and an automatic reboot cleanup service.
* 🖥️ **GDM Login Screen:** User account list is hidden (`disable-user-list=true`) and custom LPS wallpaper is configured via precompiled dconf database.
* 🔐 **Network, Kerberos, LDAP, and NFS:** Fully pre-configured with zero interactive dialogs (no blue debconf screens).

---

## 🛠️ Makefile Commands

The Makefile automates generation and distribution of all configuration files:

```bash
make help            # Display all available commands
make list-nodes      # List all nodes defined in inventory.yaml and their IPs
make generate        # Generate all files in dist/ for all workstations
make rebuild         # Clean dist/ and regenerate everything from scratch
make clean           # Remove generated files

# For Ventoy USB flash drive:
make copy-to-ventoy VENTOY_PATH=/media/$USER/Ventoy

# For Proxmox VE:
make copy-to-proxmox PVE_HOST=root@146.164.147.X
```

---

## ⚙️ 1. Configuring the Inventory (`inventory.yaml`)

The [`inventory.yaml`](file:///home/cluster/datacenter/servers/nodes/bancada/ubuntu_bootstrap_installation/inventory.yaml) file is the single source of truth for network parameters and workstation nodes.

### How to generate a secure password hash:
The Ubuntu installer does not accept plain text passwords; it requires a **SHA-512 crypt hash**. To set a custom password for the `cluster` user, run:
```bash
openssl passwd -6 "your_secret_password"
```
Copy the generated hash (e.g., `$6$rounds=4096$...`) and paste it into the `admin_password_hash` field in `inventory.yaml`.

### Adding new workstations:
Simply append new items to the `nodes` list:
```yaml
nodes:
  - hostname: "bancada11"
    ip: "146.164.147.211"
```

---

## 🚀 2. Step-by-Step Tutorial: Installation via USB Drive (Ventoy)

With Ventoy, you prepare a **single USB drive** and can install any of the registered workstations by picking it from a boot menu.

### Step 1: Install Ventoy onto the USB Drive (One-time setup)
1. Insert the USB drive into a Linux machine and identify its device path using `lsblk` (e.g., `/dev/sdb`).
2. Download and install Ventoy with GPT/UEFI support:
   ```bash
   cd /tmp
   wget https://github.com/ventoy/Ventoy/releases/download/v1.0.99/ventoy-1.0.99-linux.tar.gz
   tar -xzf ventoy-1.0.99-linux.tar.gz
   cd ventoy-1.0.99
   sudo ./Ventoy2Disk.sh -i -g /dev/sdX   # Replace sdX with your USB drive device
   ```

### Step 2: Copy the Ubuntu Server ISO
Copy the official Ubuntu Server ISO to the root of the `Ventoy` partition:
```bash
cp ubuntu-24.04-live-server-amd64.iso /media/$USER/Ventoy/
```

### Step 3: Copy Workstation Configurations
Generate and deploy all node configurations to the USB drive with a single Makefile command:
```bash
make copy-to-ventoy VENTOY_PATH=/media/$USER/Ventoy
```

### Step 4: Install on the Physical Workstation
1. Plug the USB drive into the physical workstation and boot from it (press **F11**, **F12**, or **F8** depending on motherboard).
2. Select the USB drive in UEFI mode.
3. In the Ventoy menu, pick the target workstation (e.g., `bancada01`).
4. **Done!** Ubuntu partitions the disk, sets up static IP, mounts NFS, and installs Docker and Singularity without asking for any user input. Once finished, it reboots ready for use.

---

## ☁️ 3. Step-by-Step Tutorial: Provisioning on Proxmox VE (Cloud-Init)

On Proxmox VE, provisioning leverages native **Cloud-Init Snippets** on top of official Canonical cloud images (`cloudimg`).

### Step 1: Enable Snippets in Proxmox (One-time setup)
On the Proxmox VE host terminal:
```bash
pvesm set local --content iso,vztmpl,snippets,backup
```

### Step 2: Download the Ubuntu Cloud Image (One-time setup)
On the Proxmox host terminal:
```bash
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

### Step 3: Send Generated Snippets to Proxmox
From your management machine:
```bash
make copy-to-proxmox PVE_HOST=root@<PROXMOX_IP>
```

### Step 4: Create and Start the VM in Proxmox
Run on the Proxmox host (e.g., VMID `301` for `bancada01`):
```bash
# 1. Create the basic VM
qm create 301 --name bancada01 --memory 8192 --cores 4 --net0 virtio,bridge=vmbr0

# 2. Import the cloud image disk
qm importdisk 301 noble-server-cloudimg-amd64.img local-lvm
qm set 301 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-301-disk-0 --boot c --bootdisk scsi0
qm set 301 --serial0 socket --vga serial0

# 3. Attach the Cloud-Init drive and inject the snippet
qm set 301 --ide2 local-lvm:cloudinit
qm set 301 --cicustom "user=local:snippets/bancada01.yaml"
qm set 301 --ipconfig0 ip=146.164.147.201/24,gw=146.164.147.1

# 4. Start the VM
qm start 301
```
*In under 1 minute, the VM will boot with all packages and settings fully configured.*
