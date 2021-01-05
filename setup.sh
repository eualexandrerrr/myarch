#!/usr/bin/env bash

USERNAME=mamutal91
HOSTNAME=odin

ln -s /hostlvm /run/lvm

echo "Config pacman"
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "s/#Color/Color/g" /etc/pacman.conf
sed -i "s/#TotalDownload/TotalDownload/g" /etc/pacman.conf

echo "Config mkinitpcio"
sed -i "s/block/block encrypt lvm2/g" /etc/mkinitcpio.conf

mkinitcpio -P

echo "Config sudoers"
sed -i "s/root ALL=(ALL) ALL/root ALL=(ALL) NOPASSWD: ALL\n$USERNAME ALL=(ALL) NOPASSWD:ALL/g" /etc/sudoers

# systemd
sed -i "s/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g" /etc/systemd/logind.conf
sed -i "s/#NAutoVTs=6/NAutoVTs=6/g" /etc/systemd/logind.conf

echo "Config grub"
UUID=$(blkid /dev/sda2 | awk -F '"' '{print $2}')
sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash acpi_backlight=vendor acpi_osi=Linux mitigations=off"/g' /etc/default/grub
sed -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID='$UUID':lvm"/g' /etc/default/grub
sed -i "s/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g" /etc/default/grub
sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "Add my user"
useradd -m -G wheel -s /bin/bash $USERNAME
mkdir -p /home/$USERNAME
passwd $USERNAME
passwd root

if [[ $USERNAME = "mamutal91" ]]; then
#  cryptsetup luksOpen /dev/sda3 storage
#  dd if=/dev/urandom of=/root/keyfile bs=1024 count=4
#  chmod 0400 /root/keyfile
#  cryptsetup -v luksAddKey /dev/sda3 /root/keyfile

#  UUID=$(blkid /dev/sda3 | awk -F '"' '{print $2}')
#  crypttab="storage UUID=$UUID /root/keyfile luks"
#  echo "" >> /etc/crypttab
#  echo $crypttab >> /etc/crypttab

#  echo "" >> /etc/fstab
#  echo "/dev/mapper/storage  /media/storage     ext4    defaults        0       2"

  git clone https://github.com/mamutal91/dotfiles /home/mamutal91/.dotfiles
fi

echo "Set locale, zone and keymap console"
echo KEYMAP=br-abnt2 > /etc/vconsole.conf
sed -i "s/#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/g" /etc/locale.gen
sed -i "s/#pt_BR ISO-8859-1/pt_BR ISO-8859-1/g" /etc/locale.gen
echo LANG=pt_BR.UTF-8 > /etc/locale.conf
sudo ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
locale-gen

echo $HOSTNAME > /etc/hostname

systemctl disable NetworkManager
systemctl enable dhcpcd
systemctl enable iwd
