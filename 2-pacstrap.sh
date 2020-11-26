#!/usr/bin/env bash
# github.com/mamutal91

source files/colors.sh

#curl -sSL 'https://www.archlinux.org/mirrorlist/?country=BR&protocol=http&protocol=https&ip_version=4' > /etc/pacman.d/mirrorlist

pacstrap -i /mnt base base-devel bash-completion linux linux-headers linux-firmware mkinitcpio lvm2 --noconfirm

genfstab -U /mnt >> /mnt/etc/fstab

cd .. && mv archlinux /mnt

arch-chroot /mnt

echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
echo ">>> arch-chroot /mnt"
