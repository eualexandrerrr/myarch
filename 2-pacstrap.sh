#!/usr/bin/env bash
# github.com/mamutal91
# https://www.youtube.com/channel/UCbTjvrgkddVv4iwC9P2jZFw

#rm -rf /etc/pacman.d/mirrorlist
#cp -rf files/mirrorlist /etc/pacman.d/
pacman -Sy reflector && reflector --verbose --country 'Brazil' -l 200 -p http --sort rate --save /etc/pacman.d/mirrorlist

pacstrap -i /mnt base base-devel bash-completion linux linux-headers linux-firmware mkinitcpio lvm2 --noconfirm

genfstab -U /mnt >> /mnt/etc/fstab

cd .. && mv archlinux /mnt

arch-chroot /mnt

echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
echo ">>> arch-chroot /mnt"
