# Network and Infrastruture Configuration:

This repository is responsible to hold the necessary documentation and scrits to build each 
server (service) into the lab infrastructure.

## Links:


### Nodes: 

- [Proxmox Service 1](https://146.164.147.101:8006/)
- [Proxmox Service 2](https://146.164.147.102:8006/)
- [Proxmox Caloba-v01](https://10.1.1.101:8006/)
- [Proxmox Caloba-v02](https://10.1.1.102:8006/)
- [Proxmox Caloba-v03](https://10.1.1.103:8006/)
- [Proxmox Caloba-v04](https://10.1.1.104:8006/)
- [Proxmox Caloba-v05](https://10.1.1.105:8006/)
- [Proxmox Caloba-v06](https://10.1.1.106:8006/)
- [Proxmox Caloba-v07](https://10.1.1.107:8006/)
- [Proxmox Caloba-v13](https://10.1.1.113:8006/)
- [Proxmox Caloba-v14](https://10.1.1.114:8006/)
- [Proxmox Caloba-v15](https://10.1.1.115:8006/)
- [Proxmox Caloba-v16](https://10.1.1.116:8006/)


### Queues (Cluster):

- [gpu](https://10.1.1.101:8006/)
- [cpu](https://10.1.1.112:8006/)
- [cpu-large](https://10.1.1.116:8006/)


### Services:

- [Cluster Data Center](https://cluster-server.lps.ufrj.br:8443)
- [LDAP Account Manager](http://auth-server.lps.ufrj.br/lam/)
- [Proxy Server](http://proxy-server.lps.ufrj.br:8080/login)
- [Finger Print](http://fingerprint.lps.ufrj.br)
- [Storage 1](http://storage01.lps.ufrj.br:5000)
- [Storage 2](http://storage02.lps.ufrj.br)
- [Storage 3](http://storage03.lps.ufrj.br)
- [pgadmin](http://pgadmin.lps.ufrj.br)
- [minio](http://mlflow-server.lps.ufrj.br:9001)
- [mlflow](http://mlflow-server.lps.ufrj.br:5000)
- [microtick](146.164.147.1)


## Networks:

- `10.1.1.*` internal network where all `caloba` nodes are connected.
- `146.164.147.*` external network.

## Service Nodes:

There are two physical service nodes into the network. The node `service01` is responsible
to hold the base cluster services like:

- Domain name server managed by `dns-server` virtual machine with address `146.164.147.2`.
- LDAP accounts and Kerberos passwords managed by `auth-server` virtual machine with address `146.163.147.3`.
- SLURM manager control managed by `slurm-server` virtual machine with address `146.164.147.4`.
- Login managed by `login-server` virtual machine with address `146.164.147.5`.
- VPN server managed by `vpn-server` virtual machine with address `146.164.147.6`.

The node `service02` is responsible to manager all external services like:


## Main Storage:

The main storage is named as `storage01` with address `10.1.1.202` into the network.
Into the storage we have the `market_place` folder. This folder is responsible
to hold all necessary binaries, files and keys to build the entire infrastucture
and propagate it to all nodes. All nodes has access to this folder by `NFS` service.

The location is always `/mnt/market_place` inside any node and are physically located at `10.1.1.202:/volume1/market_place` into the `storage01`.

### Market Place:

- `/mnt/market_place/data` is responsible to hold `ldap` and `kerberos` backup.
- `/mnt/market_place/module_file` is responsible to hold all binaries linked by the `module` program.
- `/mnt/market_place/nvidia` is responsible to hold all `NVIDIA` binaries.
- `/mnt/market_place/slurm_build` is responsible to hold the `slurm` binary package, the generated `murge.key` and the `slurm` configuration. All nodes are linked with these files.
- `/mnt/market_place/volumes` is responsible to hold all docker volumes like `postgres`, `openvpn` and `proxy` services.

### Homes:

Is responsible to hold all user accounts. Is physically located at `10.1.1.202:/volume1/homes`.


### Proxmox:

Is responsible to hold all proxmox backup staff. Is physically located at `10.1.1.202/volume1/proxmox`.


## Backup Storage

Not available yet

## Microtick:

Go to IP/Firewall to configure the exposed IPs and gates.

## Links and accounts (restrict access):

[Links and Accounts](https://docs.google.com/spreadsheets/d/1PbJojKlb6sLdSm6FM86nqfK1CWD7uEgIkNA54eypAy0/edit?usp=sharing)


-----

# LPS adminstrator page:

Back to the [main](https://sites.google.com/lps.ufrj.br/infra/início) page!

