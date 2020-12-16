#!/usr/bin/env bash
# github.com/mamutal91

ln -s /hostlvm /run/lvm

sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
sed -i "s/#Color/Color/g" /mnt/etc/pacman.conf

echo "Set zram"
#modprobe zram
#echo lz4 > /sys/block/zram0/comp_algorithm
#echo 32G > /sys/block/zram0/disksize
#mkswap --label zram0 /dev/zram0
#swapon --priority 100 /dev/zram0

echo "Config mirrors"
sudo pacman -S reflector --noconfirm
sudo reflector --verbose --country 'Brazil' -l 200 -p http --sort rate --save /mnt/etc/pacman.d/mirrorlist

sudo pacman -Sy efibootmgr git grub nano refind sudo wget --needed --noconfirm

echo "Set locale and zone"
sed -i "s/#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/g" /mnt/etc/locale.gen
sed -i "s/#pt_BR ISO-8859-1/pt_BR ISO-8859-1/g" /mnt/etc/locale.gen
locale-gen
echo LANG=pt_BR.UTF-8 > /mnt/etc/locale.conf
echo aspire > /mnt/etc/hostname
sudo ln -sf /mnt/usr/share/zoneinfo/America/Sao_Paulo /mnt/etc/localtime

echo "Adding my user"
useradd -m -G wheel -s /bin/bash mamutal91 && chmod +x /home/mamutal91 && chown -R mamutal91:mamutal91 /home/mamutal91
clear
passwd mamutal91
passwd root

git clone https://github.com/mamutal91/dotfiles /home/mamutal91/.dotfiles

echo "Config mkinitcpio"
mkinitcpio -p linux

lsblk -fo +partuuid

pacman -Sy iwd networkmanager --noconfirm
systemctl enable NetworkManager
systemctl enable dhcpcd
systemctl disable iwd

echo "Config grub"
refind-install --usedefault /dev/sda1
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg
