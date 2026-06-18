# Commands to be executed after:


### Add restart and reset docker as service:

```
play vm run -c "bash /mnt/market_place/scripts/datacenter/servers/nodes/slurm-node/pos_install/01_configure_docker.sh" -n caloba10-21,60-71,50
```


### Update singularity fake roots:

```
play vm run -c "python /mnt/market_place/scripts/datacenter/servers/nodes/slurm-node pos_install/02_configure_singularity.py" -n caloba10-21,60-71,50
```

### Add user into the docker group:

```
play vm run -c "usermod -aG docker USERNAME" -n caloba10-21,60-71,50
```