
#
# Add some panic contraints in case of fai
#
echo "vm.panic_on_oom=1   ;enables panic on OOM">>/etc/sysctl.conf
echo "kernel.panic=10     ;tells the kernel to reboot ten seconds after panicking">>/etc/sysctl.conf


#
# Append market_place into the mount
#

apt install -y nfs-common

mkdir -p /mnt/market_place
mkdir -p /mnt/shared/storage03/projects


echo "10.1.1.202:/volume1/market_place /mnt/market_place nfs rsize=32768,wsize=32768,bg,sync,nolock 0 0" >> /etc/fstab
echo "10.1.1.204:/shares/projects /mnt/shared/storage03/projects nfs rsize=32768,wsize=32768,bg,sync,nolock 0 0 ">> /etc/fstab

# install kerberos
apt install -y krb5-config krb5-user
apt install -y libpam-krb5
kadmin -q "addprinc -policy service -randkey host/$HOSTNAME.lps.ufrj.br"
kadmin -q "ktadd -k /etc/krb5.keytab host/$HOSTNAME.lps.ufrj.br"



# install LDAP
apt install -y libnss-ldap
apt install -y libnss-ldapd
/etc/init.d/nscd restart
/etc/init.d/ssh restart
echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=022" >> /etc/pam.d/common-session
getent passwd

# configure SSH
cp files/sshd_config /etc/ssh
invoke-rc.d ssh restart


# configure NTP
cp files/timesyncd.conf /etc/systemd/
timedatectl set-ntp true
timedatectl status


# Configure home folder
echo "10.1.1.202:/volume1/homes /home nfs rsize=32768,wsize=32768,bg,sync,nolock 0 0" >> /etc/fstab
mkdir /etc/pam_scripts
chmod -R 700 /etc/pam_scripts
chown -R root:root /etc/pam_scripts
cp files/login-logger.sh /etc/pam_scripts
chmod +x /etc/pam_scripts/login-logger.sh
echo "session required pam_exec.so /etc/pam_scripts/login-logger.sh" >> /etc/pam.d/sshd


# install others
apt install -y htop sshpass screen rsync fpart vim curl git sshpass
apt install -y python-is-python3 python3-virtualenv 
apt install -y xrdp
systemctl enable xrdp


#
# Install pyenv
#
apt install -y curl

curl https://pyenv.run | bash
echo ''
echo '# setup pyenv' >> /etc/bash.bashrc
echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> /etc/bash.bashrc
echo 'eval "$(pyenv init --path)"' >> /etc/bash.bashrc


source 03_install_singularity.sh
source 04_install_docker.sh
sudo reboot now


