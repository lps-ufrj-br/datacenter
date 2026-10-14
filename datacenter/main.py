#!/usr/bin/env python3

import re
from typing import List, Optional, Callable
import typer

from datacenter.proxmox.cluster import Cluster
from datacenter.proxmox.vm import VM
from datacenter.slurm import Slurm
from datacenter.ansible import Command

# ---------------------------------------------------------------------------
# Main Typer Application and Sub-applications
# ---------------------------------------------------------------------------

CONTEXT_SETTINGS = {"help_option_names": ["-h", "--help"]}

app = typer.Typer(
    name="play",
    help="Datacenter CLI: management and automation tool for Proxmox clusters, VMs, and SLURM.",
    no_args_is_help=True,
    add_completion=False,
    context_settings=CONTEXT_SETTINGS,
)

cluster_app = typer.Typer(
    help="Proxmox VE cluster management operations (create, reboot, ping, and destroy).",
    no_args_is_help=True,
    context_settings=CONTEXT_SETTINGS,
)

vm_app = typer.Typer(
    help="Proxmox VE Virtual Machine operations (lifecycle, snapshots, resources, and shell execution).",
    no_args_is_help=True,
    context_settings=CONTEXT_SETTINGS,
)

slurm_app = typer.Typer(
    help="SLURM cluster management operations (queue services, munge keys, and compute nodes).",
    no_args_is_help=True,
    context_settings=CONTEXT_SETTINGS,
)

app.add_typer(cluster_app, name="cluster")
app.add_typer(vm_app, name="vm")
app.add_typer(slurm_app, name="slurm")


# ---------------------------------------------------------------------------
# Helper Functions with Documentation and Typing
# ---------------------------------------------------------------------------

def convert_string_to_range(s: str) -> List[int]:
    """
    Convert a string containing individual numbers and ranges into a sorted list of integers.

    Supports simple numbers, comma-separated lists, and hyphenated ranges.

    Examples:
        >>> convert_string_to_range("0-2,20")
        [0, 1, 2, 20]
        >>> convert_string_to_range("51-54")
        [51, 52, 53, 54]
        >>> convert_string_to_range("10")
        [10]

    Args:
        s: String containing numbers and ranges to be parsed.

    Returns:
        List[int]: Expanded list of all corresponding integer values.
    """
    return sum(
        (
            i if len(i) == 1 else list(range(i[0], i[1] + 1))
            for i in ([int(j) for j in item if j] for item in re.findall(r"(\d+),?(?:-(\d+))?", s))
        ),
        [],
    )


def convert_name_in_list(s: str) -> List[str]:
    """
    Expand a node/VM naming pattern into a list of full hostnames.

    Extracts the alphabetic prefix of the host and concatenates it with each
    number produced by the numeric range expansion.

    Examples:
        >>> convert_name_in_list("caloba51")
        ['caloba51']
        >>> convert_name_in_list("caloba[51-54]")
        ['caloba51', 'caloba52', 'caloba53', 'caloba54']
        >>> convert_name_in_list("caloba10-12,20")
        ['caloba10', 'caloba11', 'caloba12', 'caloba20']

    Args:
        s: Pattern or expression containing VM names and ranges.

    Returns:
        List[str]: List containing all generated individual VM names.

    Raises:
        ValueError: If the provided pattern does not contain a valid alphabetic prefix.
    """
    match = re.match(r"([a-zA-Z]+)", s)
    if not match:
        raise ValueError(f"Invalid VM name pattern: {s}")
    name: str = match.group(1)
    return [name + str(idx) for idx in convert_string_to_range(s)]


def execute_on_vms(
    name_pattern: str,
    dry_run: bool,
    verbose: bool,
    action: Callable[[VM], None],
) -> None:
    """
    Helper function to apply an operation across multiple VMs matching a pattern.

    Expands the name pattern (e.g., 'caloba[51-54]'), instantiates each VM object,
    and executes the provided action callback.

    Args:
        name_pattern: Textual VM name pattern (e.g., 'caloba51', 'caloba[51-54]').
        dry_run: If True, simulate execution without modifying machine or hypervisor state.
        verbose: If True, enable detailed Ansible logs during execution.
        action: Callable or lambda receiving the VM instance to execute the desired operation.
    """
    names: List[str] = convert_name_in_list(name_pattern)
    print(names)
    for name in names:
        print(name)
        vm = VM(name, dry_run=dry_run, verbose=verbose)
        action(vm)


# ---------------------------------------------------------------------------
# Sub-App Commands: Cluster
# ---------------------------------------------------------------------------

@cluster_app.command("create", help="Orchestrate full creation and setup of a Proxmox VE cluster.")
def cluster_create(
    name: str = typer.Option(..., "-n", "--name", help="The name of the cluster as defined in cluster.json."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Execute the complete cluster creation workflow: reset nodes, reboot, create on master host,
    add member nodes, and run post-install configuration.
    """
    cluster = Cluster(name, dry_run=dry_run, verbose=verbose)
    cluster.create()


@cluster_app.command("destroy", help="Destroy the Proxmox VE cluster configuration and reset member nodes.")
def cluster_destroy(
    name: str = typer.Option(..., "-n", "--name", help="The name of the cluster as defined in cluster.json."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Remove corosync cluster configuration and reboot all physical nodes associated with the cluster.
    """
    cluster = Cluster(name, dry_run=dry_run, verbose=verbose)
    cluster.destroy()


@cluster_app.command("reboot", help="Reboot all physical nodes belonging to the cluster.")
def cluster_reboot(
    name: str = typer.Option(..., "-n", "--name", help="The name of the cluster to reboot."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Execute the reboot.yaml playbook across all physical nodes in the cluster.
    """
    cluster = Cluster(name, dry_run=dry_run, verbose=verbose)
    cluster.reboot()


@cluster_app.command("ping", help="Test Ansible connectivity with all physical nodes in the cluster.")
def cluster_ping(
    name: str = typer.Option(..., "-n", "--name", help="The name of the cluster to test."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Run the Ansible ping module against all physical nodes of the cluster.
    """
    cluster = Cluster(name, dry_run=dry_run, verbose=verbose)
    cluster.ping()


# ---------------------------------------------------------------------------
# Sub-App Commands: VM
# ---------------------------------------------------------------------------

@vm_app.command("create", help="Restore and provision one or more VMs from the base image.")
def vm_create(
    name: str = typer.Option(..., "-n", "--name", help="Name or pattern of the VM(s) (e.g., 'caloba51', 'caloba[51-54]')."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Restore the disk image via qmrestore, configure static networking, and reboot the virtual machine.
    """
    execute_on_vms(name, dry_run, verbose, lambda vm: vm.create())


@vm_app.command("destroy", help="Stop and permanently remove one or more VMs from the hypervisor.")
def vm_destroy(
    name: str = typer.Option(..., "-n", "--name", help="Name or pattern of the VM(s) (e.g., 'caloba51', 'caloba[51-54]')."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Execute 'qm stop' followed by 'qm destroy' including all unreferenced disks.
    """
    execute_on_vms(name, dry_run, verbose, lambda vm: vm.destroy())


@vm_app.command("ping", help="Test Ansible connectivity with one or more VMs.")
def vm_ping(
    name: str = typer.Option(..., "-n", "--name", help="Name or pattern of the VM(s) (e.g., 'caloba51', 'caloba[51-54]')."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Run Ansible ping to verify if the VM is reachable via SSH.
    """
    execute_on_vms(name, dry_run, verbose, lambda vm: vm.ping())


@vm_app.command("snapshot", help="Create a disk snapshot for one or more VMs.")
def vm_snapshot(
    name: str = typer.Option(..., "-n", "--name", help="Name or pattern of the VM(s) (e.g., 'caloba51', 'caloba[51-54]')."),
    snapshot: str = typer.Option("base", "-s", "--snapshot", help="Identifier name for the snapshot (default: 'base')."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Create a disk snapshot without saving RAM state (--vmstate 0).
    """
    execute_on_vms(name, dry_run, verbose, lambda vm: vm.snapshot(snapshot))


@vm_app.command("delsnapshot", help="Delete a previously created snapshot from one or more VMs.")
def vm_delete_snapshot(
    name: str = typer.Option(..., "-n", "--name", help="Name or pattern of the VM(s) (e.g., 'caloba51', 'caloba[51-54]')."),
    snapshot: str = typer.Option("base", "-s", "--snapshot", help="Name of the snapshot to delete (default: 'base')."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Remove the specified snapshot in Proxmox using 'qm delsnapshot'.
    """
    execute_on_vms(name, dry_run, verbose, lambda vm: vm.delete_snapshot(snapshot))


@vm_app.command("reboot", help="Reboot one or more VMs on the Proxmox host.")
def vm_reboot(
    name: str = typer.Option(..., "-n", "--name", help="Name or pattern of the VM(s) (e.g., 'caloba51', 'caloba[51-54]')."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Execute 'qm stop' followed by 'qm start' on the Proxmox host.
    """
    execute_on_vms(name, dry_run, verbose, lambda vm: vm.reboot())


@vm_app.command("stop", help="Forcefully stop one or more running VMs.")
def vm_stop(
    name: str = typer.Option(..., "-n", "--name", help="Name or pattern of the VM(s) (e.g., 'caloba51', 'caloba[51-54]')."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Execute 'qm stop' on the Proxmox hypervisor for the target VM.
    """
    execute_on_vms(name, dry_run, verbose, lambda vm: vm.stop())


@vm_app.command("start", help="Start one or more VMs that are currently stopped.")
def vm_start(
    name: str = typer.Option(..., "-n", "--name", help="Name or pattern of the VM(s) (e.g., 'caloba51', 'caloba[51-54]')."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Execute 'qm start' on the Proxmox hypervisor for the target VM.
    """
    execute_on_vms(name, dry_run, verbose, lambda vm: vm.start())


@vm_app.command("run", help="Execute shell commands remotely inside one or more VMs.")
def vm_run(
    name: str = typer.Option(..., "-n", "--name", help="Name or pattern of the VM(s) (e.g., 'caloba51', 'caloba[51-54]')."),
    command: str = typer.Option(..., "-c", "--command", help="Shell command(s) to execute remotely (supports chaining with '&&')."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Split the command string by '&&' and execute each line on the VM via Ansible playbook.
    """
    def _run_action(vm: VM) -> None:
        cmd = Command("run")
        for line in command.split("&&"):
            print(line)
            cmd += line
        vm.run_shell_on_vm(cmd)

    execute_on_vms(name, dry_run, verbose, _run_action)


@vm_app.command("options", help="Update hardware resources and boot options for one or more VMs.")
def vm_options(
    name: str = typer.Option(..., "-n", "--name", help="Name or pattern of the VM(s) (e.g., 'caloba51', 'caloba[51-54]')."),
    boot: Optional[bool] = typer.Option(None, "--boot", help="Configure whether the VM starts automatically on host boot (onboot=1)."),
    sockets: Optional[int] = typer.Option(None, "--sockets", help="Number of virtual CPU sockets."),
    cores: Optional[int] = typer.Option(None, "--cores", help="Number of CPU cores per socket."),
    memory: Optional[int] = typer.Option(None, "--memory", help="Amount of RAM allocated to the VM in Megabytes (MB)."),
    cpu: Optional[str] = typer.Option(None, "--cpu", help="Proxmox CPU emulation model (e.g., 'host', 'kvm64')."),
    balloon: Optional[int] = typer.Option(None, "--balloon", help="Minimum memory allocated for dynamic ballooning in MB (0 to disable)."),
    set_device_from_config: bool = typer.Option(False, "--set-device-from-config", help="Apply PCI/GPU passthrough configuration as defined in cluster.json."),
    remove_unused_disks: bool = typer.Option(False, "--remove-unused-disks", help="Remove residual unused disk references (unused0)."),
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Update hardware and behavior options for the VM in Proxmox VE via 'qm set'.
    """
    execute_on_vms(
        name,
        dry_run,
        verbose,
        lambda vm: vm.set_options(
            on_boot=boot,
            sockets=sockets,
            cores=cores,
            memory_mb=memory,
            cpu=cpu,
            balloon=balloon,
            set_device_from_config=set_device_from_config,
            remove_unused_disks=remove_unused_disks,
        ),
    )


# ---------------------------------------------------------------------------
# Sub-App Commands: SLURM
# ---------------------------------------------------------------------------

@slurm_app.command("restart", help="Restart and synchronize SLURM control and node services.")
def slurm_restart(
    dry_run: bool = typer.Option(False, "--dry-run", help="Execute in simulation mode without applying real changes."),
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Enable verbose output (-vv) for debugging."),
) -> None:
    """
    Synchronize the munge key across nodes, reload systemd, and restart slurmctld,
    slurmdbd, and slurmd across the cluster.
    """
    slurm = Slurm(dry_run=dry_run, verbose=verbose)
    slurm.restart()


# ---------------------------------------------------------------------------
# Entry Point
# ---------------------------------------------------------------------------

def run() -> None:
    """
    Default CLI entry point invoked by the 'play' console script.
    """
    app()


if __name__ == "__main__":
    app()