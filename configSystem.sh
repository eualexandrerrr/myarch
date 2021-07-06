#!/usr/bin/env bash

# Discover the best mirros to download packages and update pacman configs
reflector --verbose --country 'Brazil' --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "s/#Color/Color/g" /etc/pacman.conf
sed -i "s/#UseSyslog/UseSyslog/g" /etc/pacman.conf
sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 10/g" /etc/pacman.conf

# Setup locale
echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
locale-gen
localectl set-locale LANG=pt_BR.UTF-8

# Enable clock sync and set the timezone
timedatectl set-ntp 1
timedatectl set-timezone America/Sao_Paulo
hwclock --systohc

# Generate the initramfs
sed -i "s/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g" /etc/mkinitcpio.conf
sed -i "s/BINARIES=()/BINARIES=(btrfs)/g" /etc/mkinitcpio.conf
sed -i "s/block/block encrypt/g" /etc/mkinitcpio.conf
mkinitcpio -P

# Setup the bootloader
# get the device uuid
DRIVE_UUID=$(blkid /dev/disk/by-partlabel/cryptsystem | cut -d' ' -f2 | cut -d'=' -f2)
DRIVE_UUID="${DRIVE_UUID%\"}"
DRIVE_UUID="${DRIVE_UUID#\"}"

# install bootloader
bootctl --path=/boot install

# generate the arch linux entry config
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options rd.luks.name=${DRIVE_UUID}=system root=/dev/mapper/system rootflags=subvol=root rd.luks.options=discard rw
EOF

# generate the loader config
mkdir -p /boot/loader/entries
cat > /boot/loader/loader.conf <<EOF
default  arch.conf
timeout  4
console-mode max
editor   no
EOF

# Configure grub
sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash acpi_backlight=vendor nvidia-drm.modeset=1"/g' /etc/default/grub
sed -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID='$(blkid /dev/nvme0n1p2 | awk -F '"' '{print $2}')':system"/g' /etc/default/grub
sed -i "s/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g" /etc/default/grub
sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

# Configure systemd for laptop's
sed -i "s/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g" /etc/systemd/logind.conf
sed -i "s/#NAutoVTs=6/NAutoVTs=6/g" /etc/systemd/logind.conf

# Mount HDD storage
if [[ $user == mamutal91 ]]; then
  git clone https://github.com/mamutal91/dotfiles /home/mamutal91/.dotfiles
  sed -i "s/https/ssh/g" /home/mamutal91/.dotfiles/.git/config
  sed -i "s/github/git@github/g" /home/mamutal91/.dotfiles/.git/config
fi

# Services
systemctl disable NetworkManager
systemctl enable dhcpcd
systemctl enable iwd
