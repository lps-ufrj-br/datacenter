#export ANSIBLE_HOST_KEY_CHECKING=False
#ansible-playbook -i hosts playbooks/post_install.yaml

#cd /mnt/market_place/scripts/lps-cluster
#cd external/bancada
cp files/gdm /etc/dconf/profile
mkdir -p /etc/dconf/db/gdm.d
cp files/00-login-screen /etc/dconf/db/gdm.d/
cp files/10-customization-screen /etc/dconf/db/gdm.d/
dconf update

