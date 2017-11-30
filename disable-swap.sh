sudo swapoff  /dev/dm-1
sudo sed -i '/swap/d' /etc/fstab
sudo lvremove /dev/mapper/VolGroup00-LogVol01 -y