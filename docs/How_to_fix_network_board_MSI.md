
nano /etc/apt/sources.list.d/pve-enterprise.list


nano /etc/apt/sources.list.d/ceph.list



nano /etc/apt/sources.list


deb http://ftp.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://ftp.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

# Repositório Gratuito do Proxmox VE 8
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription

# Repositório Gratuito do Ceph Quincy
deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription

apt clean
apt update



apt update
apt install build-essential git dkms pve-headers-$(uname -r) -y


cd /usr/src
git clone https://github.com/awesometic/realtek-r8125-dkms.git
cd realtek-r8125-dkms


./dkms-install.sh


modprobe r8125
ip -br link show