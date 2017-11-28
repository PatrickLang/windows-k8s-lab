sudo swapoff  /dev/dm-1
sudo set -i '/swap/d' /etc/fstab
sudo lvremove /dev/mapper/VolGroup00-LogVol01 -y
