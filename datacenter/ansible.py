__all__ = ["Command", "Playbook"]

import os
import traceback
import tempfile
from typing import Dict, List, Optional, Any

from datacenter import get_host_path, get_playbook_path, get_master_key


class Command:
    """
    Shell command builder and chain executor for remote operations via Ansible.
    
    Allows chaining successive commands using the `+` operator, grouping them
    with `&&` at execution time.
    """

    def __init__(self, description: str) -> None:
        """
        Initialize the command object with a human-readable description.

        Args:
            description: Title or description of the action being performed.
        """
        self.description: str = description
        self.command: List[str] = []

    def __add__(self, command: str) -> "Command":
        """
        Add a command line or instruction to the chained list.

        Args:
            command: Shell command string.

        Returns:
            Command: The current Command instance with the new command appended.
        """
        self.command.append(command)
        return self

    def __call__(self) -> str:
        """
        Concatenate all queued commands using the '&&' operator.

        Returns:
            str: Combined shell command line string ready for execution.
        """
        return " && ".join(self.command)


class Playbook:
    """
    Base class for running Ansible automation playbooks and commands on datacenter hosts.
    """

    def __init__(
        self,
        host_path: str = get_host_path(),
        dry_run: bool = False,
        verbose: bool = False,
        envs: Optional[Dict[str, str]] = None,
    ) -> None:
        """
        Initialize the Playbook execution handler with the specified parameters.

        Args:
            host_path: Path to the Ansible hosts/inventory file.
            dry_run: If True, simulate execution without making real changes to the system.
            verbose: If True, enable verbose Ansible output (-vv) for debugging.
            envs: Optional dictionary of environment variables passed to Ansible.
                  Default: {"ANSIBLE_HOST_KEY_CHECKING": "False"}.
        """
        self.host_path: str = host_path
        self.dry_run: bool = dry_run
        self.verbose: bool = verbose
        self.envs: Dict[str, str] = envs if envs is not None else {"ANSIBLE_HOST_KEY_CHECKING": "False"}

    def ping_hosts(self, hosts: str) -> None:
        """
        Execute an Ansible connectivity ping against the specified hosts.

        Args:
            hosts: Target host pattern, group, or name (e.g., 'cpu-large', 'caloba51').
        """
        preexec = " && ".join([f"export {key}={value}" for key, value in self.envs.items()])

        with tempfile.TemporaryDirectory() as temp_dir:
            print(f"Temporary directory created at: {temp_dir}")
            file_path = os.path.join(temp_dir, "hosts")

            with open(file_path, "w") as f:
                with open(self.host_path, mode="r") as f_original:
                    for line in f_original.readlines():
                        f.write(line.replace("$CLUSTER_MASTER_KEY", get_master_key()))
                print(f.name)

            command = f"{preexec} && ansible {hosts} -m ping -v -i {file_path}"
            os.system(command)

    def run_shell(
        self,
        hosts: str,
        command: Command,
        script: str = "shell.yaml",
    ) -> bool:
        """
        Execute a Command object on the specified hosts via the shell.yaml playbook.

        Args:
            hosts: Target host pattern, group, or name.
            command: Command object containing instructions and description.
            script: Playbook filename (default: "shell.yaml").

        Returns:
            bool: True if the playbook ran successfully, False otherwise.
        """
        params: Dict[str, str] = {
            "command": f"'{command()}'",
            "description": f"'{command.description}'",
        }
        return self.run(script, hosts, params)

    def run(
        self,
        script: str,
        hosts: str,
        params: Optional[Dict[str, Any]] = None,
    ) -> bool:
        """
        Execute a parameterized Ansible playbook on the specified hosts.

        Args:
            script: Name or relative path of the playbook file.
            hosts: Target hosts for playbook execution.
            params: Optional dictionary of extra parameters passed via -e flag.

        Returns:
            bool: True if execution succeeded, False on error.
        """
        if params is None:
            params = {}

        script_path = f"{get_playbook_path()}/{script}"
        merged_params: Dict[str, Any] = {"hosts": hosts, **params}
        preexec = " && ".join([f"export {key}={value}" for key, value in self.envs.items()])
        params_str = " ".join([f"{key}={value}" for key, value in merged_params.items()])

        ok = False
        with tempfile.TemporaryDirectory() as temp_dir:
            print(f"Temporary directory created at: {temp_dir}")
            file_path = os.path.join(temp_dir, "hosts")

            with open(file_path, "w") as f:
                with open(self.host_path, mode="r") as f_original:
                    for line in f_original.readlines():
                        f.write(line.replace("$CLUSTER_MASTER_KEY", get_master_key()))
                print(f.name)

            command = f'{preexec} && ansible-playbook -i {file_path} {script_path} -e "{params_str}"'

            if self.verbose:
                command += " -vv"
            print(command)
            try:
                if not self.dry_run:
                    os.system(command)
                ok = True
            except Exception:
                traceback.print_exc()
        return ok        


