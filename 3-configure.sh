files/#!/bin/bash
# github.com/mamutal91
# https://www.youtube.com/channel/UCbTjvrgkddVv4iwC9P2jZFw

ln -s /hostlvm /run/lvm

sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "s/#Color/Color/g" /etc/pacman.conf

modprobe zram
echo lz4 > /sys/block/zram0/comp_algorithm
sed -i "s/0/32GB/g" /sys/block/zram0/disksize
mkswap --label zram0 /dev/zram0
swapon --priority 100 /dev/zram0

echo "Config mirrors"
rm -rf /etc/pacman.d/mirrorlist
mv files/mirrorlist /etc/pacman.d/

sudo pacman -Sy efibootmgr git grub nano refind sudo wget --needed --noconfirm

echo "Set locale and zone"
sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen
sed -i "s/#en_US ISO-8859-1/en_US ISO-8859-1/g" /etc/locale.gen
sed -i "s/#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/g" /etc/locale.gen
sed -i "s/#pt_BR ISO-8859-1/pt_BR ISO-8859-1/g" /etc/locale.gen
locale-gen
echo LANG=pt_BR.UTF-8 > /etc/locale.conf
echo aspire > /etc/hostname
sudo ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

echo "Adding my user"
useradd -m -G wheel -s /bin/bash mamutal91 && chmod +x /home/mamutal91
clear
passwd mamutal91
passwd root
chown -R mamutal91:mamutal91 /home/mamutal91
chmod +x /home/mamutal91

git clone https://github.com/mamutal91/dotfiles /home/mamutal91/.dotfiles

echo "Config sudoers"
rm -rf /etc/sudoers
mv files/sudoers /etc/

echo "Config mkinitcpio"
rm -rf /etc/mkinitcpio.conf
mv files/mkinitcpio.conf /etc/
mkinitcpio -p linux

lsblk -fo +partuuid

echo "Config grub"
UUID=$(blkid /dev/sda2 | awk -F '"' '{print $2}')
sed -i "s/SEU_ID_AQUI/$UUID/g" files/grub
rm -rf /etc/default/grub
mv files/grub /etc/default

pacman -Sy iwc --noconfirm
systemctl enable iwd

echo "Config grub"
refind-install --usedefault /dev/sda1
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "exit / umount -R / reboot"
