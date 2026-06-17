__all__ = ["VM"]


import argparse

from time               import sleep
from typing             import Union
from datacenter.ansible import Playbook, Command
from datacenter         import get_cluster_config
from datacenter         import get_argparser_formatter




class VM(Playbook):
  
    def __init__(self,
               vm_name  : str,
               dry_run  : bool=True,
               verbose  : bool=False,
               ):
        Playbook.__init__(self, dry_run=dry_run, verbose=verbose)
        self.vm_name = vm_name
        self.cluster_config = get_cluster_config()
        self.vm_init_name = self.cluster_config['images']['hostname']

    def vm(self, key : str) -> Union[str,int]:
        return self.cluster_config['vm'][self.vm_name][key]

    def image(self) -> str:
        return self.cluster_config['images']['paths'][self.vm("image")]

    def ping(self):
        self.ping_hosts(self.vm_name)


    def run_shell_on_vm(self, 
                         command : Command,
                         ) -> bool:
        return self.run_shell(self.vm_name, command)
    

    def run_shell_on_host(self, 
                                 command : Command
                                 ) -> bool:
        vm_host = self.vm("host")
        return self.run_shell(vm_host, command)
    
    
    #
    #
    #


    def restore(self) -> bool:

        image      = self.image()    
        vmid       = self.vm("vmid")
        sockets    = self.vm("sockets")
        cores      = self.vm("cores")
        memory_mb  = self.vm("memory_mb")
        storage    = self.vm("storage")
        vm_name    = self.vm("vm_name") 

        command = Command("restore vm...")
        #command+= f"pvesm set {storage} --format qcow2"
        command+= f"qmrestore {image} {vmid} --storage {storage} --unique --force"
        command+= f"qm set {vmid} --name {vm_name} --sockets {sockets} --cores {cores} --memory {memory_mb} --cpu host --balloon 0"
        command+= f"qm start {vmid}"
        command+= f"qm set {vmid} --delete unused0"
        return self.run_shell_on_host(command)
    
    
    def snapshot(self, name : str) -> bool:
        vmid  = self.vm("vmid")
        command = Command(f"snapshot vm {self.vm_name}...")
        command+= f"qm snapshot {vmid} {name}"
        return self.run_shell_on_host(command)


    def reboot(self) -> bool:
        vmid  = self.vm("vmid")
        command = Command(f"reboot vm {self.vm_name}...")
        command+= f"qm stop {vmid} && qm start {vmid}"
        return self.run_shell_on_host(command)
  
    def stop(self) -> bool:
        vmid  = self.vm("vmid")
        command = Command(f"stop vm {self.vm_name}...")
        command+= f"qm stop {vmid}"
        return self.run_shell_on_host(command)
  
    def start(self) -> bool:
        vmid  = self.vm("vmid")
        command = Command(f"start vm {self.vm_name}...")
        command+= f"qm start {vmid}"
        return self.run_shell_on_host(command)
    

    def configure_network(self) -> bool:
        ip_address = self.vm("ip_address")
        script_http = "https://raw.githubusercontent.com/lps-ufrj-br/datacenter/refs/heads/main/data/scripts/configure_network.sh" 
        script_name = script_http.split("/")[-1]
        command = Command(f"configure network on vm {self.vm_name}...")
        command+= f"wget {script_http} && bash {script_name} {self.vm_name} {ip_address}"
        params  = {
              "command"    : f"'{command()}'",
              "ip_address" : f"'{ip_address}'",
              "vm_name"    : self.vm_name,
        }
    
        return self.run("configure_network.yaml", self.vm_init_name, params)
    
    def set_options(self, 
                     on_boot:bool = None,
                     sockets:int = None,
                     cores:int = None,
                     memory_mb:int = None,
                     cpu:int = None,
                     balloon:int = None,
                     set_device_from_config : bool = False,
                     remove_unused_disks : bool = False,
                     ) -> bool: 
        vmid  = self.vm("vmid")
        command = Command(f"set VM options...")
        
        if on_boot is not None:
            onboot = 1 if on_boot else 0
            command+= f"qm set {vmid} --onboot {onboot}"
            
        if sockets is not None:
            command+= f"qm set {vmid} --sockets {sockets}"

        if cores is not None:
            command+= f"qm set {vmid} --cores {cores}"
        
        if memory_mb is not None:
            command+= f"qm set {vmid} --memory {memory_mb}"
        
        if cpu is not None:
            command+= f"qm set {vmid} --cpu {cpu}"
        
        if balloon is not None:
            command+= f"qm set {vmid} --balloon {balloon}"

        if set_device_from_config:
          device = self.vm("pci")
          if device!="":
            command+= f"qm set {vmid} -hostpci0 '{device},pcie=1,rombar=1,x-vga=0'"

        if remove_unused_disks:
            command+= f"qm set {vmid} --delete unused0"

        return self.run_shell_on_host(command)
    
   


    #
    # VM operations
    #
 
    def destroy(self) -> bool:
        vmid = self.vm("vmid")
        command = Command(f"destroy vm {self.vm_name}...")
        command+= f"qm stop {vmid} && qm destroy {vmid} --destroy-unreferenced-disks"
        return self.run_shell_on_host(command)
     
  
    def create(self, snapname : str="base") -> bool:  
        print(f"restore image into the host...")  
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

      

#
# Parsers
#

def common_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,  formatter_class=get_argparser_formatter())
  parser.add_argument('--dry-run', action='store_true', dest='dry_run', required = False,
                      help = "dry run...")
  parser.add_argument('-v','--verbose', action='store_true', dest='verbose', required = False, 
                      help = "Set as verbose output.")
  parser.add_argument('-n','--name', action='store', dest='name', required = True,
                    help = "The name of the vm.")
  return parser

def vm_create_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,  formatter_class=get_argparser_formatter())
  return [common_parser(),parser]

def vm_destroy_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,  formatter_class=get_argparser_formatter())
  return [common_parser(),parser] 
  
def vm_ping_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,  formatter_class=get_argparser_formatter())
  return [common_parser(),parser] 

def vm_run_command_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,  formatter_class=get_argparser_formatter())
  parser.add_argument('-c','--command', action='store', dest='command', required = True, 
                      help = "Run the command, in line")
  return [common_parser(),parser] 
  
def vm_snapshot_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,  formatter_class=get_argparser_formatter())
  parser.add_argument('-s','--snapshot', action='store', dest='snapshot', required = False, 
                      help = "The name of the snapshot.", default='base')
  return [common_parser(),parser] 

def vm_reboot_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,  formatter_class=get_argparser_formatter())
  return [common_parser(),parser]

def vm_stop_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,  formatter_class=get_argparser_formatter())
  return [common_parser(),parser]

def vm_start_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,  formatter_class=get_argparser_formatter())
  return [common_parser(),parser]

def vm_set_options_parser():
  parser = argparse.ArgumentParser(description = '', add_help = False,  formatter_class=get_argparser_formatter())
  parser.add_argument('--boot', action='store_true', dest='boot', required = False, 
                      help = "Enable the VM to start on boot.")
  parser.add_argument('--sockets', action='store', dest='sockets', required = False, 
                      help = "The number of sockets.")
  parser.add_argument('--cores', action='store', dest='cores', required = False, 
                      help = "The number of cores.")
  parser.add_argument('--memory', action='store', dest='memory', required = False, 
                      help = "The amount of memory in MB.")
  parser.add_argument('--cpu', action='store', dest='cpu', required = False, 
                      help = "The CPU model.")
  parser.add_argument('--balloon', action='store', dest='balloon', required = False, 
                      help = "The amount of balloon memory in MB.")
  parser.add_argument('--set-device-from-config', action='store_true', dest='set_device_from_config', required = False, 
                      help = "The PCI device.")

  parser.add_argument('--remove-unused-disks', action='store_true', dest='remove_unused_disks', required = False, 
                      help = "Remove unused disks.")
  return [common_parser(),parser] 