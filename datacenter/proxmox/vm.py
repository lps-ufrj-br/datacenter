__all__ = ["VM"]

from time import sleep
from typing import Union, Optional, Any, Dict
from datacenter.ansible import Playbook, Command
from datacenter import get_cluster_config


class VM(Playbook):
    """
    Lifecycle and hardware configuration manager for Proxmox VE Virtual Machines (VMs) via Ansible.
    
    Provides operations to create/restore VMs from base images, manage snapshots,
    adjust hardware resources (CPU, RAM, PCI passthrough), and execute remote shell commands.
    """

    def __init__(
        self,
        vm_name: str,
        dry_run: bool = False,
        verbose: bool = False,
    ) -> None:
        """
        Initialize the virtual machine manager for the specified VM.

        Args:
            vm_name: VM identifier name as mapped in cluster.json (e.g., 'caloba51').
            dry_run: If True, simulate execution without making real changes on the hypervisor.
            verbose: If True, enable verbose Ansible output (-vv).
        """
        super().__init__(dry_run=dry_run, verbose=verbose)
        self.vm_name: str = vm_name
        self.cluster_config: Dict[str, Any] = get_cluster_config()
        self.vm_init_name: str = self.cluster_config["images"]["hostname"]

    def vm(self, key: str) -> Any:
        """
        Retrieve a VM configuration property from cluster.json.

        Args:
            key: Property name (e.g., 'vmid', 'host', 'sockets', 'cores', 'memory_mb', 'storage').

        Returns:
            Any: Configured value for this VM property.
        """
        return self.cluster_config["vm"][self.vm_name][key]

    def image(self) -> str:
        """
        Return the absolute file path to the base image used to restore the VM.

        Returns:
            str: Path to the Proxmox backup/image file (vma/qcow2).
        """
        return self.cluster_config["images"]["paths"][self.vm("image")]

    def ping(self) -> None:
        """
        Test Ansible ping connectivity to the VM.
        """
        self.ping_hosts(self.vm_name)

    def run_shell_on_vm(self, command: Command) -> bool:
        """
        Execute a sequence of shell commands directly inside the VM guest OS.

        Args:
            command: Command object containing the shell instructions.

        Returns:
            bool: True if the command ran successfully inside the VM.
        """
        return self.run_shell(self.vm_name, command)

    def run_shell_on_host(self, command: Command) -> bool:
        """
        Execute a sequence of shell commands on the Proxmox host hypervisor where the VM resides.

        Args:
            command: Command object with hypervisor commands (e.g., qm, pvesm).

        Returns:
            bool: True if the command ran successfully on the hypervisor.
        """
        vm_host: str = self.vm("host")
        return self.run_shell(vm_host, command)

    #
    # VM Lifecycle Operations
    #

    def restore(self) -> bool:
        """
        Restore the VM from the base image defined in cluster.json via `qmrestore`.

        Configures sockets, cores, RAM, CPU model, and removes residual unreferenced disks.

        Returns:
            bool: True if the restoration completed successfully.
        """
        image = self.image()
        vmid = self.vm("vmid")
        sockets = self.vm("sockets")
        cores = self.vm("cores")
        memory_mb = self.vm("memory_mb")
        storage = self.vm("storage")
        vm_name = self.vm("vm_name")

        command = Command("restore vm...")
        command += f"qmrestore {image} {vmid} --storage {storage} --unique --force"
        command += f"qm set {vmid} --name {vm_name} --sockets {sockets} --cores {cores} --memory {memory_mb} --cpu host --balloon 0"
        command += f"qm start {vmid}"
        command += f"qm set {vmid} --delete unused0"
        return self.run_shell_on_host(command)

    def snapshot(self, name: str) -> bool:
        """
        Create a disk snapshot of the virtual machine (`qm snapshot`).

        Args:
            name: Identifier name for the snapshot to create.

        Returns:
            bool: True if the snapshot was created successfully.
        """
        vmid = self.vm("vmid")
        command = Command(f"snapshot vm {self.vm_name}...")
        command += f"qm snapshot {vmid} {name} --vmstate 0"
        return self.run_shell_on_host(command)

    def delete_snapshot(self, name: str) -> bool:
        """
        Delete a previously created snapshot from the virtual machine (`qm delsnapshot`).

        Args:
            name: Name of the snapshot to delete.

        Returns:
            bool: True if the snapshot was deleted successfully.
        """
        vmid = self.vm("vmid")
        command = Command(f"delete snapshot vm {self.vm_name}...")
        command += f"qm delsnapshot {vmid} {name}"
        return self.run_shell_on_host(command)

    def reboot(self) -> bool:
        """
        Reboot the virtual machine by stopping and starting its process on the hypervisor.

        Returns:
            bool: True if the VM was rebooted successfully.
        """
        vmid = self.vm("vmid")
        command = Command(f"reboot vm {self.vm_name}...")
        command += f"qm stop {vmid} && qm start {vmid}"
        return self.run_shell_on_host(command)

    def stop(self) -> bool:
        """
        Forcefully stop the virtual machine (`qm stop`).

        Returns:
            bool: True if the VM was stopped successfully.
        """
        vmid = self.vm("vmid")
        command = Command(f"stop vm {self.vm_name}...")
        command += f"qm stop {vmid}"
        return self.run_shell_on_host(command)

    def start(self) -> bool:
        """
        Start the virtual machine on the Proxmox host (`qm start`).

        Returns:
            bool: True if the VM started successfully.
        """
        vmid = self.vm("vmid")
        command = Command(f"start vm {self.vm_name}...")
        command += f"qm start {vmid}"
        return self.run_shell_on_host(command)

    def configure_network(self) -> bool:
        """
        Execute remote script on the VM to configure its static IP address and hostname.

        Returns:
            bool: True if the network configuration playbook completed successfully.
        """
        ip_address = self.vm("ip_address")
        script_http = "https://raw.githubusercontent.com/lps-ufrj-br/datacenter/refs/heads/main/data/scripts/configure_network.sh"
        script_name = script_http.split("/")[-1]
        command = Command(f"configure network on vm {self.vm_name}...")
        command += f"wget {script_http} && bash {script_name} {self.vm_name} {ip_address}"
        params = {
            "command": f"'{command()}'",
            "ip_address": f"'{ip_address}'",
            "vm_name": self.vm_name,
        }
        return self.run("configure_network.yaml", self.vm_init_name, params)

    def set_options(
        self,
        on_boot: Optional[bool] = None,
        sockets: Optional[int] = None,
        cores: Optional[int] = None,
        memory_mb: Optional[int] = None,
        cpu: Optional[str] = None,
        balloon: Optional[int] = None,
        set_device_from_config: bool = False,
        remove_unused_disks: bool = False,
    ) -> bool:
        """
        Update hardware and runtime options for the VM (`qm set`).

        Args:
            on_boot: If True, set the VM to start automatically on host boot.
            sockets: Number of virtual CPU sockets.
            cores: Number of cores per virtual socket.
            memory_mb: RAM memory allocated to the VM in Megabytes (MB).
            cpu: CPU emulation model (e.g., 'host', 'kvm64').
            balloon: Minimum memory in MB for dynamic memory ballooning (0 to disable).
            set_device_from_config: If True, apply PCI/GPU passthrough configuration.
            remove_unused_disks: If True, delete unreferenced disk allocations (unused0).

        Returns:
            bool: True if options were applied successfully on the hypervisor.
        """
        vmid = self.vm("vmid")
        command = Command("set VM options...")

        if on_boot is not None:
            onboot = 1 if on_boot else 0
            command += f"qm set {vmid} --onboot {onboot}"

        if sockets is not None:
            command += f"qm set {vmid} --sockets {sockets}"

        if cores is not None:
            command += f"qm set {vmid} --cores {cores}"

        if memory_mb is not None:
            command += f"qm set {vmid} --memory {memory_mb}"

        if cpu is not None:
            command += f"qm set {vmid} --cpu {cpu}"

        if balloon is not None:
            command += f"qm set {vmid} --balloon {balloon}"

        if set_device_from_config:
            device = self.vm("pci")
            if device != "":
                command += f"qm set {vmid} -hostpci0 '{device},pcie=1,rombar=1,x-vga=0'"

        if remove_unused_disks:
            command += f"qm set {vmid} --delete unused0"

        return self.run_shell_on_host(command)

    def destroy(self) -> bool:
        """
        Stop and permanently destroy the VM and all its associated disk images.

        Returns:
            bool: True if destruction completed successfully.
        """
        vmid = self.vm("vmid")
        command = Command(f"destroy vm {self.vm_name}...")
        command += f"qm stop {vmid} && qm destroy {vmid} --destroy-unreferenced-disks"
        return self.run_shell_on_host(command)

    def create(self, snapname: str = "base") -> bool:
        """
        Orchestrate the complete creation of a virtual machine:
        1. Restore base image onto the Proxmox host
        2. Wait for system initialization
        3. Configure static network via Ansible playbook
        4. Reboot the VM

        Args:
            snapname: Optional name of the baseline snapshot (default: "base").

        Returns:
            bool: True if all steps completed successfully.
        """
        print("restore image into the host...")
        ok = self.restore()
        sleep(40)
        if not ok:
            return False
        print(f"configure network into {self.vm_name}")
        ok = self.configure_network()
        if not ok:
            return False
        self.reboot()
        return True 