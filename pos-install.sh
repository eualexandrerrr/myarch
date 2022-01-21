#!/usr/bin/env bash

# Get the device uuid
SSD2_UUID=$(blkid $SSD2 | awk -F '"' '{print $2}')
SSD3_UUID=$(blkid $SSD3 | awk -F '"' '{print $2}')

# Set user and hostname
useradd -m -G wheel -s /bin/bash $USERNAME
mkdir -p /home/$USERNAME
echo $HOSTNAME > /etc/hostname

# Configure hosts
echo "127.0.0.1	localhost
::1		localhost
127.0.1.1	odin" | tee /etc/hosts

# Discover the best mirros to download packages and update pacman configs
reflector --verbose --country 'Brazil' --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "s/#Color/Color/g" /etc/pacman.conf
sed -i "s/#UseSyslog/UseSyslog/g" /etc/pacman.conf
sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 10/g" /etc/pacman.conf

# Setup locate and time
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
sed -i "s/#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/g" /etc/locale.gen
sed -i "s/#pt_BR ISO-8859-1/pt_BR ISO-8859-1/g" /etc/locale.gen
sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen
sed -i "s/#en_US ISO-8859-1/en_US ISO-8859-1/g" /etc/locale.gen
echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
locale-gen
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

# SSHD
sed -i "s/#AllowTcpForwarding/AllowTcpForwarding/g" /etc/ssh/sshd_config
sed -i "s/AllowTcpForwarding no/AllowTcpForwarding yes/g" /etc/ssh/sshd_config

# Generate the initramfs
sed -i "s/BINARIES=()/BINARIES=(btrfs)/g" /etc/mkinitcpio.conf
sed -i "s/block/block encrypt/g" /etc/mkinitcpio.conf
mkinitcpio -p linux-lts

# Setup the bootloader
# install bootloader
bootctl --path=/boot install

# generate the arch linux entry config
mkdir -p /boot/loader/entries
cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options rd.luks.name=${SSD3_UUID}=system root=/dev/mapper/system rootflags=subvol=root rd.luks.options=discard rw
EOF

# generate the loader config
cat > /boot/loader/loader.conf << EOF
default  arch.conf
timeout  4
console-mode max
editor   no
EOF

# Configure grub
sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT=saved/g' /etc/default/grub
sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash acpi_backlight=vendor nvidia-drm.modeset=1"/g' /etc/default/grub
sed -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID='${SSD3_UUID}':cryptsystem"/g' /etc/default/grub
sed -i 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g' /etc/default/grub
sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/g' /etc/default/grub
sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/g' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

# Configure systemd for laptop's
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g' /etc/systemd/logind.conf
sed -i 's/#NAutoVTs=6/NAutoVTs=6/g' /etc/systemd/logind.conf

# Services
systemctl disable NetworkManager
systemctl enable dhcpcd
systemctl enable iwd

# graphics driver
nvidia=$(lspci | grep -e VGA -e 3D | grep 'NVIDIA' 2> /dev/null || echo '')
if [[ -n $nvidia ]]; then
  pacman -S nvidia-lts nvidia-settings nvidia-utils nvidia-dkms nvidia-utils nvidia-prime opencl-nvidia mesa mesa-demos vulkan-tools lib32-nvidia-utils lib32-opencl-nvidia lib32-virtualgl lib32-nvidia-utils lib32-libvdpau lib32-opencl-nvidia lib32-mesa --noconfirm
  sed -i "s/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g" /etc/mkinitcpio.conf
  mkinitcpio -p linux-lts
fi

# Sudo configs
sed -i "s/root ALL=(ALL) ALL/root ALL=(ALL) NOPASSWD: ALL\n$USERNAME ALL=(ALL) NOPASSWD:ALL/g" /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL$/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

# My notebook
mountStorages() {
  # Storage 2
  STORAGE_HDD_UUID=$(blkid $STORAGE_HDD | awk -F '"' '{print $2}')
  mkdir -p /mnt/hdd
  echo -e "\nhdd UUID=$STORAGE_HDD_UUID /root/keyHDD luks" >> /etc/crypttab
  echo -e "\n# HDD" >> /etc/fstab
  echo "/dev/mapper/hdd  /mnt/hdd     btrfs    defaults        0       2" >> /etc/fstab
  dd if=/dev/urandom of=/root/keyHDD bs=1024 count=4
  chmod 0400 /root/keyHDD
  clear
  echo "Type crypt password $STORAGE_HDD"
  cryptsetup -v luksAddKey $STORAGE_HDD /root/keyHDD
}

if [[ $USERNAME == mamutal91 ]]; then
  mountStorages

  # Zen kernel
  pacman -S linux-zen linux-zen-headers --noconfirm
  mkinitcpio -p linux-zen
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
  grub-mkconfig -o /boot/grub/grub.cfg
fi

# Define passwords
clear
echo "Type user password $USERNAME"
passwd $USERNAME && clear
echo "Type user password root"
passwd root

if [[ $USERNAME == mamutal91 ]]; then
  git clone https://github.com/mamutal91/dotfiles /home/mamutal91/.dotfiles
  sed -i 's/https/ssh/g' /home/mamutal91/.dotfiles/.git/config
  sed -i 's/github/git@github/g' /home/mamutal91/.dotfiles/.git/config
fi

chown -R $USERNAME:$USERNAME /home/$USERNAME
