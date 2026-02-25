__all__ = ["Cluster"]

import argparse

from time             import sleep
from typing           import Dict, List
from datacenter.ansible import Playbook, Command
from datacenter         import get_cluster_config, get_master_key, get_argparser_formatter

class Cluster(Playbook):
  
    def __init__(self, 
                 cluster_name : str,
                 dry_run      : bool=False,
                 verbose      : bool=False,
               ):
        Playbook.__init__(self, dry_run=dry_run, verbose=verbose)
        self.cluster_name   = cluster_name
        self.cluster_config = get_cluster_config()


    def cluster(self, key : str) -> str:
        return self.cluster_config['cluster'][self.cluster_name][key]
       

    def storages(self) -> List[Dict[str,str]]:
        storages = self.cluster_config['storage']
        return [ { "name":name,'server':d['server'],'path':d['path']} for name, d in storages.items()]


    def ping(self):
        self.ping_hosts(self.cluster_name)


    def run_shell_on_all(self, 
                         command : Command
                         ) -> bool:
        return self.run_shell(self.cluster_name, command)
    

    def run_script_on_all(self, script_name : str, params : Dict={}) -> bool:
        return self.run(script_name, self.cluster_name, params)
  
  
    def run_shell_on_master_host(self, 
                                 command : Command
                                 ) -> bool:
        cluster_master_host = self.cluster("host")
        return self.run_shell(cluster_master_host, command)
    
    #
    # Cluster operations
    #

    def reset(self) -> bool:

        print(f"reset the cluster with name {self.cluster}")
        command = Command("reset nodes...")
        command+= "systemctl stop pve-cluster corosync"
        command+= "pmxcfs -l"
        command+= "rm -rf /etc/corosync/*"
        command+= "rm -rf /etc/pve/corosync.conf"
        command+= "killall pmxcfs"
        command+= "systemctl start pve-cluster"
        command+= "rm -rf /etc/pve/nodes/*"
        return self.run_shell_on_all(command)
    
    
    def reboot(self) -> bool:
        return self.run_script_on_all("reboot.yaml")
    
    
    def create_cluster(self) -> bool:
        cluster_master_host = self.cluster("host")
        print(f"create cluster into the host {cluster_master_host} for cluster {self.cluster_name}")
        command = Command("create cluster...")
        command+= f"pvecm create {self.cluster_name} --votes 1"
        #command+= f"pvesm set storage01 --format qcow2"
        return self.run_shell_on_master_host(command)


    def create_nodes(self) -> bool:
        print(f"add nodes into the cluster {self.cluster}...")
        ip_address = self.cluster('ip_address')
        params = {
           "ip_address" : f"'{ip_address}'",
           "master_key" : f"'{get_master_key()}'"
        }
        return self.run_script_on_all("add_node.yaml", params)


    def create_storage(self, storage : Dict[str,str]) -> bool:
      storage_name = storage['name']
      ip_address   = storage['server']
      path         = storage['path']
      print(f"add storage {storage_name} into the cluster {self.cluster}...")
      command = Command("add storages...")
      command+= f"pvesm add nfs {storage_name} --server {ip_address} --export {path} --content iso,backup,images"
      return self.run_shell_on_master_host(command)


    def configure_nodes(self) -> bool:
      script_http = "https://raw.githubusercontent.com/lps-ufrj-br/datacenter/refs/heads/main/data/scripts/configure_node.py"
      script_name = script_http.split("/")[-1]
      command     = Command("configure nodes...")
      command    += f"wget {script_http} && python3 {script_name}"
      ok = self.run_shell_on_all(command)
      if not ok:
        print("it is not possible to configure nodes...")
      return self.reboot() if ok else False

    #
    # High level operations
    #
    
    def destroy(self) -> bool:
      self.reset()
      self.reboot()


    def create(self) -> bool:


      print(f"[step 1] resetting all nodes into the cluster {self.cluster}...")
      ok = self.reset()
      if not ok:
        print(f"[step 1] it is not possible to reset all nodes")
        return False

      print(f"[step 2] reboot all nodes into the cluster {self.cluster_name}...")
      ok = self.reboot()
      if not ok:
        print(f"[step 2] it is not possible to reboot all nodes")
        return False

      sleep(30)
      print(f"[step 3] create the cluster with name {self.cluster_name}...")
      ok = self.create_cluster()
      if not ok:
        print(f"[step 3] it is not possible to create the cluster with name {self.cluster_name}")
        return False

      sleep(10)
      print(f"[step 4] add nodes into the cluster {self.cluster_name}...")

      ok = self.create_nodes()
      if not ok:
        print(f"[step 4] it is not possible to add nodes the cluster {self.cluster}")
        return False

      sleep(5)
      print(f"[step 5] configure all nodes into the cluster {self.cluster}...")
      ok = self.configure_nodes()
      if not ok:
        print(f"[step 5] it is not possible to configure all nodes into the cluster {self.cluster}")
        return False

      return True 


#
# Parsers
#

def common_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,  formatter_class=get_argparser_formatter())
  
  parser.add_argument('--dry-run', action='store_true', dest='dry_run', required = False,
                      help = "Set as dry run.")
  parser.add_argument('-v','--verbose', action='store_true', dest='verbose', required = False, 
                      help = "Set as verbose.")
  return parser

def cluster_create_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,
                                   formatter_class=get_argparser_formatter())
  parser.add_argument('-n','--name', action='store', dest='name', required = True,
                      help = "The name of the cluster.")
  return [common_parser(), parser]

def cluster_destroy_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,
                                   formatter_class=get_argparser_formatter())
  parser.add_argument('-n','--name', action='store', dest='name', required = True,
                      help = "The name of the cluster.")
  return [common_parser(), parser]

def cluster_reboot_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,
                                   formatter_class=get_argparser_formatter())
  parser.add_argument('-n','--name', action='store', dest='name', required = True,
                      help = "The name of the cluster.")
  return [common_parser(), parser]

def cluster_ping_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,
                                   formatter_class=get_argparser_formatter())
  parser.add_argument('-n','--name', action='store', dest='name', required = True,
                      help = "The name of the cluster.")
  return [common_parser(),parser]

