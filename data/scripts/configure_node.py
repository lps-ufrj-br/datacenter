import os, subprocess
from tempfile import mkstemp
from shutil import move, copymode
from os import fdopen, remove

dry_run = False

def replace(file_path, pattern, subst):
    fh, abs_path = mkstemp()
    with fdopen(fh,'w') as new_file:
        with open(file_path) as old_file:
            for line in old_file:
                if pattern in line:
                    new_file.write(subst+"\n")
                else:
                    new_file.write(line)
    copymode(file_path, abs_path)
    remove(file_path)
    move(abs_path, file_path)
    
pci_devices = subprocess.check_output(['lspci']).decode()
devices = []
for device in pci_devices.split('\n'):
    if "NVIDIA" in device and "VGA" in device:
        devices.append(device[:5])
        

if len(devices)>0:
    pci_ids = []
    print(devices)
    for device in devices:
        output = subprocess.check_output(['lspci', '-s', device, '-n']).decode()[:-1]
        pci_ids.extend( [ o.split(' ')[-3] for o in output.split('\n')] )
        
    pci_ids = ','.join(list(set(pci_ids)))
    print(pci_ids)
    GRUB_CMDLINE_LINUX_DEFAULT=f'GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on pcie_acs_override=downstream,multifunction initcall_blacklist=sysfb_init video=vesa:off vfio-pci.ids={pci_ids} vfio_iommu_type1.allow_unsafe_interrupts=1 kvm.ignore_msrs=1 modprobe.blacklist=radeon,nouveau,nvidia,nvidiafb,nvidia-gpu"'
    print(GRUB_CMDLINE_LINUX_DEFAULT)
    if not dry_run:
        replace(f"/etc/default/grub" , "GRUB_CMDLINE_LINUX_DEFAULT", GRUB_CMDLINE_LINUX_DEFAULT)
        os.system("update-grub")
    modules = ["vfio","vfio_iommu_type1","vfio_pci","vfio_virqfd"]
    with open("/etc/modules",'w') as f:
        for module in modules:
            f.write(f"{module}\n")
    if not dry_run:
        os.system("update-initramfs -u -k all")
else:
    print("current host has no GPUs installed")