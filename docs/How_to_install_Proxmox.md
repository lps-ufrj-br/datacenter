# Proxmox configuration

Proxmox is an open-source platform for enterprise virtualization. It is a hyper-converged infrastructure that integrates the KVM hypervisor for full virtualization of virtual machines (VMs) and Linux Containers (LXC) for container-based virtualization on a single platform. It allows you to manage VMs and containers, along with software-defined storage and networking, high-availability clustering, and other tools, all through an integrated web interface.

### **1. Proxmox Installation**

#### **Booting from a Live USB**

1.  Boot from the Proxmox VE 8.1 live USB stick. Be sure to choose the **UEFI** entry in the boot menu.
2.  In the TUI installer, move the cursor to the installation option.
3.  Press **`e`** to edit the boot options.
4.  Replace `vga=xxx` at the end of the line with **`nomodeset`**.
5.  Press **`Ctrl-X`** to boot with your changes.

#### **BIOS Setup**

Before installation, ensure that these features are enabled in your motherboard's BIOS:

  * **Intel Virtualization Technology**
  * **VT-d**

**Note:** For MSI motherboard, `disable secure boot`, `swith boot to custom` and `disable CState` on Intel CPU.

-----

### **2. GPU Passthrough Configuration**

This section is only for Proxmox nodes that will be used for GPU passthrough.

1.  **Find the GPU Device's PCI Address:**
    First, you need to find the PCI address of your GPU. Run the following command in the Proxmox shell:

    ```bash
    lspci -nnv | grep VGA
    ```

    The output should look similar to this:

    ```
    01:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU104 [GeForce RTX 2080 SUPER] [10de:1e81] (rev a1) (prog-if 00 [VGA controller])
    ```

    The PCI address is the first part, in this case, `01:00.0`.

2.  **Find All Devices in the IOMMU Group:**
    The GPU is part of a group of PCI devices. Use the following command to list all devices in the group:

    ```bash
    lspci -s 01:00
    ```

    The output will list all associated devices, such as the VGA controller, audio device, and other controllers.

3.  **Get Device IDs:**
    To get the IDs of all devices in the group, run the following command:

    ```bash
    lspci -s 01:00 -n
    ```

    The output will provide the IDs you need to passthrough. You're looking for the pairs of numbers like `10de:1e81`.

4.  **Edit the GRUB Configuration File:**
    Now, edit the `grub` configuration file:

    ```bash
    nano /etc/default/grub
    ```

    Find the line that starts with `GRUB_CMDLINE_LINUX_DEFAULT` and add the device IDs you found earlier, as shown in this example for an Intel CPU:

    ```
    GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on pcie_acs_override=downstream,multifunction initcall_blacklist=sysfb_init video=vesa:off vfio-pci.ids=10de:1e81,10de:10f8,10de:1ad8,10de:1ad9 vfio_iommu_type1.allow_unsafe_interrupts=1 kvm.ignore_msrs=1 modprobe.blacklist=radeon,nouveau,nvidia,nvidiafb,nvidia-gpu"
    ```

    Save the changes and then update GRUB:

    ```bash
    update-grub
    ```

5.  **Add VFIO Modules:**
    Edit the `/etc/modules` file to enable PCI passthrough:

    ```bash
    nano /etc/modules
    ```

    Add the following lines to the end of the file:

    ```
    # Modules required for PCI passthrough
    vfio
    vfio_iommu_type1
    vfio_pci
    vfio_virqfd
    ```

    Save and exit the editor.

6.  **Update and Reboot:**
    Update the initial RAM file system and then reboot the server to apply all changes:

    ```bash
    update-initramfs -u -k all
    reboot
    ```

7.  **Verify IOMMU is Enabled:**
    After rebooting, check that IOMMU is enabled with this command:

    ```bash
    dmesg | grep -e DMAR -e IOMMU
    ```

    The output should contain a line that says `DMAR: IOMMU enabled`.

8.  **Verify the GPU's IOMMU Group:**
    Finally, confirm that your GPU is in a separate IOMMU group by running this script:

    ```bash
    #!/bin/bash
    shopt -s nullglob
    for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
        echo "IOMMU Group ${g##*/}:"
        for d in $g/devices/*; do
            echo -e "\t$(lspci -nns ${d##*/})"
        done;
    done;
    ```

    Your Proxmox host is now ready for GPU passthrough.

-----

### **3. Proxmox Cluster Management**

#### **Creating a New Cluster**

1.  Choose a node to be the main cluster node and open an SSH connection to it:
    ```bash
    ssh root@caloba-v01.lps.ufrj.br
    ```
2.  Create the cluster with the command below:
    ```bash
    pvecm create caloba
    ```

#### **Adding a Node to a Cluster**

For each new node, run the following command to register it with the cluster:

```bash
pvecm add 10.1.1.101
```

> **Note:** Clusters do not work well with more than 10 nodes, so it is recommended to create multiple sub-clusters if you have more than 10 nodes.

#### **Resetting Cluster Configuration**

If you need to reset the cluster configuration on a node, run these commands:

```bash
systemctl stop pve-cluster corosync
pmxcfs -l
rm -rf /etc/corosync/*
rm -rf /etc/pve/corosync.conf
killall pmxcfs
systemctl start pve-cluster
rm -rf /etc/pve/nodes/*
```

-----

### **4. Adding NFS Storage**

To add an NFS storage share to your cluster, follow these steps:

1.  In the web interface, navigate to the **Datacenter** view.
2.  Click on **Storage**, then **Add**, and select the **NFS plugin**.
3.  Use the following configuration to attach the storage:
      * **ID**: `storage01`
      * **Server**: `10.1.1.202`
      * **Location**: `/volume1/proxmox`
      * **Content**: Select **Disk**, **ISO**, **backup**, and **snipped**.
4.  Click **Add** to make the storage available to the entire cluster.


## Snapshot not supported error in NFS storage:

To fixed it, access one proxmox node and type:

```
pvesm set <STORAGE_ID> --format qcow2
```

-----

# LPS adminstrator page:

Back to the [main](https://sites.google.com/lps.ufrj.br/infra/início) page!

