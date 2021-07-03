#!/usr/bin/env bash

clear

read -p "You user? [ enter = mamutal91 ]: " username
read -p "You hostname? [ enter = odin ]: " hostname
[[ -z $username ]] && username=mamutal91 || username=$username
[[ -z $hostname ]] && hostname=odin || hostname=$hostname
echo -e "\nUSER: $username\nHOST: $hostname\n"

ln -s /hostlvm /run/lvm

echo "Config pacman"
reflector -c Brazil --sort score --save /etc/pacman.d/mirrorlist
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "s/#Color/Color/g" /etc/pacman.conf
sed -i "s/#UseSyslog/UseSyslog/g" /etc/pacman.conf
sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 10/g" /etc/pacman.conf

echo "Config mkinitpcio"
sed -i "s/block/block encrypt lvm2/g" /etc/mkinitcpio.conf
sed -i "s/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g" /etc/mkinitcpio.conf
mkinitcpio -P

echo "Config sudoers"
sed -i "s/root ALL=(ALL) ALL/root ALL=(ALL) NOPASSWD: ALL\n$username ALL=(ALL) NOPASSWD:ALL/g" /etc/sudoers

# systemd
sed -i "s/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g" /etc/systemd/logind.conf
sed -i "s/#NAutoVTs=6/NAutoVTs=6/g" /etc/systemd/logind.conf

echo "Config grub"
UUID=$(blkid /dev/nvme0n1p2 | awk -F '"' '{print $2}')

bootctl install

mkdir -p /boot/loader/entries

echo "title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options cryptdevice=UUID=\"$UUID\":cryptroot:allow-discards root=/dev/mapper/arch-root rw" > /boot/loader/entries/arch.conf
echo "default arch.conf" >> /boot/loader/loader.conf

sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash acpi_backlight=vendor nvidia-drm.modeset=1"/g' /etc/default/grub
sed -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID='$UUID':lvm"/g' /etc/default/grub
sed -i "s/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g" /etc/default/grub
sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "Add my user"
useradd -m -G wheel -s /bin/bash $username
mkdir -p /home/$username

if [[ $username == "mamutal91" ]]; then
  git clone https://github.com/mamutal91/dotfiles /home/$username/.dotfiles
  sed -i "s/https/ssh/g" /home/$username/.dotfiles/.git/config
  sed -i "s/github/git@github/g" /home/$username/.dotfiles/.git/config
fi

echo "Set locale, zone and keymap console"
echo KEYMAP=br-abnt2 > /etc/vconsole.conf
sed -i "s/#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/g" /etc/locale.gen
sed -i "s/#pt_BR ISO-8859-1/pt_BR ISO-8859-1/g" /etc/locale.gen
sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen
sed -i "s/#en_US ISO-8859-1/en_US ISO-8859-1/g" /etc/locale.gen
echo LANG=pt_BR.UTF-8 > /etc/locale.conf
locale-gen
sudo ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

echo $hostname > /etc/hostname

# Mount HDD storage
if [[ $username == mamutal91 ]]; then
  mkdir -p /mnt/media/storage
  echo "" >> /etc/crypttab
  echo "storage UUID=$(blkid /dev/sda1 | awk -F '"' '{print $2}') /root/keyfile luks" >> /etc/crypttab
  echo "" >> /etc/fstab
  echo "# Storage" >> /etc/fstab
  echo "/dev/mapper/storage  /media/storage     ext4    defaults        0       2" >> /etc/fstab
  dd if=/dev/urandom of=/root/keyfile bs=1024 count=4
  chmod 0400 /root/keyfile
  cryptsetup -v luksAddKey /dev/sda1 /root/keyfile
fi

# Services
systemctl disable NetworkManager
systemctl enable dhcpcd
systemctl enable iwd

clear
echo "Set passwords"
passwd $username
passwd root
