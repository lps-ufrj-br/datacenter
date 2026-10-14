__all__ = ["Cluster"]

from time import sleep
from typing import Dict, List, Optional, Any
from datacenter.ansible import Playbook, Command
from datacenter import get_cluster_config, get_master_key


class Cluster(Playbook):
    """
    Proxmox VE cluster infrastructure manager and Ansible automation orchestrator.
    
    Allows creating member nodes, attaching storages, rebooting physical hosts,
    and destroying or recreating Proxmox clusters in an automated fashion.
    """

    def __init__(
        self,
        cluster_name: str,
        dry_run: bool = False,
        verbose: bool = False,
    ) -> None:
        """
        Initialize the Proxmox cluster manager.

        Args:
            cluster_name: Cluster identifier name as defined in cluster.json.
            dry_run: If True, simulate execution without applying real changes.
            verbose: If True, enable verbose Ansible output.
        """
        super().__init__(dry_run=dry_run, verbose=verbose)
        self.cluster_name: str = cluster_name
        self.cluster_config: Dict[str, Any] = get_cluster_config()

    def cluster(self, key: str) -> Any:
        """
        Retrieve a specific configuration value for the current cluster.

        Args:
            key: Configuration key (e.g., 'host', 'ip_address').

        Returns:
            Any: Configured value in cluster.json for the specified key.
        """
        return self.cluster_config["cluster"][self.cluster_name][key]

    def storages(self) -> List[Dict[str, str]]:
        """
        Return the list of NFS storages configured for the cluster.

        Returns:
            List[Dict[str, str]]: List with name, server, and export path details.
        """
        storages: Dict[str, Dict[str, str]] = self.cluster_config["storage"]
        return [{"name": name, "server": d["server"], "path": d["path"]} for name, d in storages.items()]

    def ping(self) -> None:
        """
        Test Ansible ping connectivity to all physical nodes in the cluster.
        """
        self.ping_hosts(self.cluster_name)

    def run_shell_on_all(self, command: Command) -> bool:
        """
        Execute a sequence of shell commands on all nodes in the cluster.

        Args:
            command: Command object containing the shell sequence.

        Returns:
            bool: True if the command ran successfully across all nodes.
        """
        return self.run_shell(self.cluster_name, command)

    def run_script_on_all(self, script_name: str, params: Optional[Dict[str, Any]] = None) -> bool:
        """
        Execute an Ansible playbook on all nodes belonging to the cluster.

        Args:
            script_name: Playbook filename (e.g., 'reboot.yaml').
            params: Optional dictionary of additional execution parameters.

        Returns:
            bool: True if the playbook completed successfully.
        """
        return self.run(script_name, self.cluster_name, params or {})

    def run_shell_on_master_host(self, command: Command) -> bool:
        """
        Execute a sequence of shell commands exclusively on the cluster master host.

        Args:
            command: Command object containing the commands to execute.

        Returns:
            bool: True if the command ran successfully on the master host.
        """
        cluster_master_host: str = self.cluster("host")
        return self.run_shell(cluster_master_host, command)

    #
    # Low-level cluster operations
    #

    def reset(self) -> bool:
        """
        Reset the Proxmox cluster state (corosync and pve-cluster) across all nodes.

        Returns:
            bool: True if the reset completed successfully.
        """
        print(f"reset the cluster with name {self.cluster_name}")
        command = Command("reset nodes...")
        command += "systemctl stop pve-cluster corosync"
        command += "pmxcfs -l"
        command += "rm -rf /etc/corosync/*"
        command += "rm -rf /etc/pve/corosync.conf"
        command += "killall pmxcfs"
        command += "systemctl start pve-cluster"
        command += "rm -rf /etc/pve/nodes/*"
        return self.run_shell_on_all(command)

    def reboot(self) -> bool:
        """
        Reboot all physical nodes in the cluster using the reboot.yaml playbook.

        Returns:
            bool: True if reboot was successfully triggered.
        """
        return self.run_script_on_all("reboot.yaml")

    def create_cluster(self) -> bool:
        """
        Initialize the Proxmox cluster definition on the master host (`pvecm create`).

        Returns:
            bool: True if the cluster was created on the master.
        """
        cluster_master_host: str = self.cluster("host")
        print(f"create cluster into the host {cluster_master_host} for cluster {self.cluster_name}")
        command = Command("create cluster...")
        command += f"pvecm create {self.cluster_name} --votes 1"
        return self.run_shell_on_master_host(command)

    def create_nodes(self) -> bool:
        """
        Join member nodes to the Proxmox cluster via the add_node.yaml playbook.

        Returns:
            bool: True if nodes were added successfully.
        """
        print(f"add nodes into the cluster {self.cluster_name}...")
        ip_address: str = self.cluster("ip_address")
        params: Dict[str, str] = {
            "ip_address": f"'{ip_address}'",
            "master_key": f"'{get_master_key()}'",
        }
        return self.run_script_on_all("add_node.yaml", params)

    def create_storage(self, storage: Dict[str, str]) -> bool:
        """
        Attach an NFS storage to the Proxmox cluster on the master host (`pvesm add nfs`).

        Args:
            storage: Dictionary containing 'name', 'server', and 'path'.

        Returns:
            bool: True if the storage was attached successfully.
        """
        storage_name = storage["name"]
        ip_address = storage["server"]
        path = storage["path"]
        print(f"add storage {storage_name} into the cluster {self.cluster_name}...")
        command = Command("add storages...")
        command += f"pvesm add nfs {storage_name} --server {ip_address} --export {path} --content iso,backup,images"
        return self.run_shell_on_master_host(command)

    def configure_nodes(self) -> bool:
        """
        Download and run the node post-install configuration script and reboot nodes.

        Returns:
            bool: True if the nodes were configured and rebooted successfully.
        """
        script_http = "https://raw.githubusercontent.com/lps-ufrj-br/datacenter/refs/heads/main/data/scripts/configure_node.py"
        script_name = script_http.split("/")[-1]
        command = Command("configure nodes...")
        command += f"wget {script_http} && python3 {script_name}"
        ok = self.run_shell_on_all(command)
        if not ok:
            print("it is not possible to configure nodes...")
        return self.reboot() if ok else False

    #
    # High-level cluster operations
    #

    def destroy(self) -> bool:
        """
        Destroy the Proxmox cluster by resetting corosync configurations and rebooting nodes.

        Returns:
            bool: True if reset and reboot completed successfully.
        """
        ok_reset = self.reset()
        ok_reboot = self.reboot()
        return ok_reset and ok_reboot

    def create(self) -> bool:
        """
        Orchestrate complete cluster creation in 5 steps:
        1. Reset all nodes
        2. Reboot all nodes
        3. Create cluster definition on the master host
        4. Join remaining nodes to the cluster
        5. Run post-configuration on all nodes

        Returns:
            bool: True if all 5 steps completed successfully.
        """
        print(f"[step 1] resetting all nodes into the cluster {self.cluster_name}...")
        if not self.reset():
            print("[step 1] it is not possible to reset all nodes")
            return False

        print(f"[step 2] reboot all nodes into the cluster {self.cluster_name}...")
        if not self.reboot():
            print("[step 2] it is not possible to reboot all nodes")
            return False

        sleep(30)
        print(f"[step 3] create the cluster with name {self.cluster_name}...")
        if not self.create_cluster():
            print(f"[step 3] it is not possible to create the cluster with name {self.cluster_name}")
            return False

        sleep(10)
        print(f"[step 4] add nodes into the cluster {self.cluster_name}...")
        if not self.create_nodes():
            print(f"[step 4] it is not possible to add nodes into the cluster {self.cluster_name}")
            return False

        sleep(5)
        print(f"[step 5] configure all nodes into the cluster {self.cluster_name}...")
        if not self.configure_nodes():
            print(f"[step 5] it is not possible to configure all nodes into the cluster {self.cluster_name}")
            return False

        return True

