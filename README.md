[![pages](https://github.com/lps-ufrj-br/datacenter/actions/workflows/pages.yml/badge.svg)](https://github.com/lps-ufrj-br/datacenter/actions/workflows/pages.yml)


## Datacenter ([Website](https://lps-ufrj-br.github.io/datacenter))


This repository contains all scripts and topology of the Caloba cluster. The Caloba cluster is a High-Performance Computing (HPC) environment based on SLURM, designed to efficiently manage and schedule jobs across multiple nodes, providing users with the resources they need for computational tasks.

* [infrastructure installation](servers/README.md)
* 💻 [Proxmox Installation](docs/How_to_install_Proxmox.md): A guide to installing and configuring a Proxmox server, including steps for GPU passthrough and cluster management.
* 🐧 [Debian Installation](docs/How_to_Install_Debian.md): Instructions for setting up a new Debian system.
* 🔑 [Account Creation](docs/How_to_create_account.md): A step-by-step process for creating new user accounts with LDAP and Kerberos.
* 💾 [Bootable Pendrive](docs/How_to_create_bootable_pendrive.md): Instructions for create a bootable pendrive on Linux or MacOS.
* [sbatch](docs/How_to_use_sbatch.md)
* [singularity build](docs/How_to_build_a_singularity_image.md)
* [singularity usage](docs/How_to_use_singularity.md)
* [slurm](docs/How_to_use_slurm.md)



### Recreate the cluster

```
play cluster create -n cpu-large
```

### Reboot all physical nodels

```
play cluster reboot -n cpu-large
```

### Restore a node into the cluster:

```
play vm create -n caloba51
```

### Destroy a node into the cluster:

```
play vm destroy -n caloba51
```

### Install a package into a nodes:

```
play vm run -c "sudo apt install -y new_package && source /mnt/market_place/scripts/install_root.sh" -n caloba[51-54]
```

### Update singularity fake roots:

```
play vm run -c "python /mnt/market_place/scripts/datacenter/data/scripts/configure_singularity.py" -n caloba[51-54]
```


# Commands to be executed after:


### Add restart and reset docker as service:

```
play vm run -c "bash /mnt/market_place/scripts/datacenter/servers/nodes/slurm-node/pos_install/01_configure_docker.sh" -n caloba10-21,60-71,50
```


### Update singularity fake roots:

```
play vm run -c "python /mnt/market_place/scripts/datacenter/servers/nodes/slurm-node/pos_install/02_configure_singularity.py" -n caloba10-21,60-71,50
```

### Add user into the docker group:

```
play vm run -c "usermod -aG docker USERNAME" -n caloba10-21,60-71,50
```


### Installnvidia container toolkit:

```
play vm run -c "bash /mnt/market_place/scripts/datacenter/servers/nodes/slurm-node/pos_install/03_configure_docker_gpu_toolkit.sh" -n caloba10-21,60-71,50
```

