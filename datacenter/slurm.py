__all__ = ["Slurm"]

from typing import Dict, Any, Optional
from datacenter.ansible import Playbook, Command
from datacenter import get_cluster_config


class Slurm(Playbook):
    """
    Service manager and automation orchestrator for the High-Performance Computing (HPC) SLURM cluster.
    
    Manages control daemons (`slurmctld`), accounting (`slurmdbd`),
    authentication (`munge`), and job execution workers (`slurmd`) across master and compute nodes.
    """

    def __init__(
        self,
        dry_run: bool = False,
        verbose: bool = False,
    ) -> None:
        """
        Initialize the SLURM manager.

        Args:
            dry_run: If True, simulate execution without making real changes.
            verbose: If True, enable verbose Ansible output.
        """
        super().__init__(dry_run=dry_run, verbose=verbose)
        self.cluster_config: Dict[str, Any] = get_cluster_config()

    def run_script_on_all(self, command: Command) -> bool:
        """
        Execute a shell command sequence across all SLURM compute nodes (group 'vm').

        Args:
            command: Command object containing the shell command sequence.

        Returns:
            bool: True if the command ran successfully across all nodes.
        """
        return self.run_shell("vm", command)

    def run_script_on_master(self, command: Command) -> bool:
        """
        Execute a shell command sequence on the SLURM master control node (host 'slurmctld').

        Args:
            command: Command object containing the shell command sequence.

        Returns:
            bool: True if the command ran successfully on the master node.
        """
        return self.run_shell("slurmctld", command)

    def run_script_on_entrypoint(self, command: Command) -> bool:
        """
        Execute a shell command sequence on the SLURM login / entrypoint node (host 'login').

        Args:
            command: Command object containing the shell command sequence.

        Returns:
            bool: True if the command ran successfully on the login node.
        """
        return self.run_shell("login", command)

    def ping(self) -> None:
        """
        Test Ansible ping connectivity to all SLURM compute nodes.
        """
        self.ping_hosts("vm")

    def restart(self) -> None:
        """
        Restart and synchronize SLURM and Munge services across the cluster:
        1. Update and propagate munge keys (/etc/munge/munge.key)
        2. Restart munge, slurmdbd, and slurmctld daemons on the master host
        3. Reload configurations via `scontrol reconfigure`
        4. Restart munge and slurmd across all compute nodes
        5. Restart munge on the login node
        """
        command = Command("Restart slurm control...")
        command += "cp /etc/munge/munge.key /mnt/market_place/slurm_build"
        command += "sudo systemctl daemon-reload"
        command += "sudo systemctl start munge"
        command += "sudo systemctl enable slurmdbd"
        command += "sudo systemctl start slurmdbd"
        command += "sudo systemctl enable slurmctld"
        command += "sudo systemctl start slurmctld"
        command += "sudo scontrol reconfigure"
        self.run_script_on_master(command)

        command = Command("Update munge key...")
        command += "cp /mnt/market_place/slurm_build/munge.key /etc/munge/"
        command += "chown munge:munge /etc/munge/munge.key"
        command += "chmod 400 /etc/munge/munge.key"
        command += "systemctl enable munge"
        command += "systemctl restart munge"
        command += "systemctl enable slurmd"
        command += "systemctl restart slurmd"
        self.run_script_on_all(command)

        command = Command("Update munge key...")
        command += "cp /mnt/market_place/slurm_build/munge.key /etc/munge/"
        command += "chown munge:munge /etc/munge/munge.key"
        command += "chmod 400 /etc/munge/munge.key"
        command += "systemctl enable munge"
        command += "systemctl restart munge"
        self.run_script_on_entrypoint(command)


