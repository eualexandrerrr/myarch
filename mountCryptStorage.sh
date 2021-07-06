#!/usr/bin/env bash

echo "Formatting storage"
cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 --use-random -i 100 /dev/sda1
cryptsetup luksOpen /dev/sda1 storage
mkfs.ext4 /dev/mapper/storage

cryptsetup luksOpen /dev/sda1 storage
dd if=/dev/urandom of=/root/keyfile bs=1024 count=4
chmod 0400 /root/keyfile
cryptsetup -v luksAddKey /dev/sda1 /root/keyfile

UUID=$(blkid /dev/sda1 | awk -F '"' '{print $2}')
crypttab="storage UUID=$UUID /root/keyfile luks"
echo "" >> /etc/crypttab
echo $crypttab >> /etc/crypttab

echo "" >> /etc/fstab
echo "/dev/mapper/storage  /media/storage     ext4    defaults        0       2"

# temp
mkdir -p /mnt/media/storage
echo "" >> /etc/crypttab
echo "storage UUID=$(blkid /dev/sda1 | awk -F '"' '{print $2}') /root/keyfile luks" >> /etc/crypttab
echo "" >> /etc/fstab
echo "# Storage" >> /etc/fstab
echo "/dev/mapper/storage  /media/storage     ext4    defaults        0       2" >> /etc/fstab
dd if=/dev/urandom of=/root/keyfile bs=1024 count=4
chmod 0400 /root/keyfile
clear
echo Type passwd hd storage
cryptsetup -v luksAddKey /dev/sda1 /root/keyfile
