__all__ = []

import os
import json
from typing import Dict, Any

def get_cluster_config() -> Dict[str, Any]:
    """
    Load and return the cluster configuration dictionary from JSON.

    Reads the base configuration path from the DATACENTER_DATA_PATH environment variable.

    Returns:
        Dict[str, Any]: Configuration dictionary for clusters, nodes, images, and storages.
    """
    data_path = os.environ.get("DATACENTER_DATA_PATH")
    with open(f"{data_path}/cluster.json", "r") as f:
        return json.load(f)

def get_host_path() -> str:
    """
    Return the path to the Ansible inventory hosts file.

    Returns:
        str: Absolute path to the hosts inventory file.
    """
    data_path = os.environ.get("DATACENTER_DATA_PATH")
    return f"{data_path}/hosts"

def get_playbook_path() -> str:
    """
    Return the base directory where Ansible playbooks are located.

    Returns:
        str: Absolute path to the playbooks directory.
    """
    playbook_path = os.environ.get("DATACENTER_DATA_PATH")
    return f"{playbook_path}/playbooks"

def get_master_key() -> str:
    """
    Retrieve the cluster administrative master key from the CLUSTER_MASTER_KEY environment variable.

    Returns:
        str: Master key string.
    """
    return os.environ.get("CLUSTER_MASTER_KEY", "")

from . import ansible
__all__.extend( ansible.__all__ )
from .ansible import * 

from . import proxmox
__all__.extend( proxmox.__all__ )
from .proxmox import *

from . import slurm 
__all__.extend( slurm.__all__ )
from .slurm import *
