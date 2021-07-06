#!/usr/bin/env bash

# Get the device uuid
DISK2_UUID=$(blkid /dev/disk/by-partlabel/$DISK2 | cut -d' ' -f2 | cut -d'=' -f2) && DISK2_UUID="${DRIVE_UUID%\"}" && DISK2_UUID="${DISK2_UUID#\"}"
DISK3_UUID=$(blkid /dev/disk/by-partlabel/$DISK3 | cut -d' ' -f2 | cut -d'=' -f2) && DISK3_UUID="${DISK3_UUID%\"}" && DISK3_UUID="${DISK3_UUID#\"}"

# Discove
r the best mirros to download packages and update pacman configs
reflector --verbose --country 'Brazil' --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "s/#Color/Color/g" /etc/pacman.conf
sed -i "s/#UseSyslog/UseSyslog/g" /etc/pacman.conf
sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 10/g" /etc/pacman.conf

# Setup locale
echo -e "pt_BR.UTF-8 UTF-8\npt_BR ISO-8859-1" > /etc/locale.gen
echo -e "en_US.UTF-8 UTF-8\nen_US ISO-8859-1" >> /etc/locale.gen
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
locale-gen
localectl set-locale LANG=pt_BR.UTF-8

# Enable clock sync and set the timezone
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

# Generate the initramfs
sed -i "s/BINARIES=()/BINARIES=(btrfs)/g" /etc/mkinitcpio.conf
sed -i "s/block/block encrypt/g" /etc/mkinitcpio.conf
mkinitcpio -P

# Setup the bootloader
# install bootloader
bootctl --path=/boot install

# generate the arch linux entry config
mkdir -p /boot/loader/entries
cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options rd.luks.name=${DISK3_UUID}=system root=/dev/mapper/system rootflags=subvol=root rd.luks.options=discard rw
EOF

# generate the loader config
cat > /boot/loader/loader.conf << EOF
default  arch.conf
timeout  4
console-mode max
editor   no
EOF

# Configure grub
sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash acpi_backlight=vendor nvidia-drm.modeset=1"/g' /etc/default/grub
sed -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID='${DISK3_UUID}':cryptsystem"/g' /etc/default/grub
sed -i 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' /etc/default/grub
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
amd=$(lspci | grep -e VGA -e 3D | grep 'AMD' 2> /dev/null || echo '')
intel=$(lspci | grep -e VGA -e 3D | grep 'Intel' 2> /dev/null || echo '')
if [[ -n $nvidia   ]]; then
  pacman -S nvidia nvidia-settings nvidia-utils nvidia-dkms opencl-nvidia
  sed -i "s/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g" /etc/mkinitcpio.conf
  mkinitcpio -P
fi

if [[ -n $amd ]]; then
  pacman -S --noconfirm xf86-video-amdgpu
fi

if [[ -n $intel ]]; then
  pacman -S --noconfirm xf86-video-intel
  gpasswd -a $username bumblebee
  systemctl enable bumblebeed
fi

clear

# User configs
useradd -m -G wheel -s /bin/bash $USERNAME
sed -i "s/root ALL=(ALL) ALL/root ALL=(ALL) NOPASSWD: ALL\n$USERNAME ALL=(ALL) NOPASSWD:ALL/g" /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL$/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

mkdir -p /home/$USERNAME
echo $HOSTNAME > /etc/hostname

# Define passwords
pacman -Sy expect --noconfirm
expect -c "
set newpass \"$PASSWORD\"
spawn sudo passwd $USERNAME
expect \".*ew password: \"
send \"$newpass\n\"
expect \".*etype new password: \"
send \"$newpass\n\"
spawn sudo passwd root
expect \".*ew password: \"
send \"$newpass\n\"
expect \".*etype new password: \"
send \"$newpass\n\"
interact" &> /dev/null

if [[ $HAVE_STORAGE == true ]]; then
  STORAGE_UUID=$(blkid /dev/disk/by-partlabel/$STORAGE | cut -d' ' -f2 | cut -d'=' -f2) && STORAGE_UUID="${STORAGE_UUID%\"}" && STORAGE_UUID="${STORAGE_UUID#\"}"

  mkdir -p /mnt/media/storage
  echo -e "\nstorage UUID=$STORAGE_UUID /root/keyfile luks" >> /etc/crypttab
  echo -e "\n# Storage" >> /etc/fstab
  echo "/dev/mapper/storage  /media/storage     btrfs    defaults        0       2" >> /etc/fstab
  dd if=/dev/urandom of=/root/keyfile bs=1024 count=4
  chmod 0400 /root/keyfile
  expect -c "
  set newpass \"$PASSWORD\"
  spawn cryptsetup -v luksAddKey /dev/sda1 /root/keyfile
  expect \".*nter any existing passphrase: \"
  send \"$newpass\n\"
  interact"
fi

# My notebook
if [[ $USERNAME == mamutal91 ]]; then
  wget https://raw.githubusercontent.com/mamutal91/dotfiles/master/setup/packages.sh && chmod +x packages.sh
  for i in ${packages[@]}; do
    pacman -Sy ${i} --needed --noconfirm
  done
  for aur in $aur; do
      echo "Installing $aur"
      git clone https://aur.archlinux.org/$aur
      cd $aur || exit
      makepkg -si --skippgpcheck --noconfirm --needed
      cd - || exit
      rm -rf $aur
  done
  git clone https://github.com/mamutal91/dotfiles /home/mamutal91/.dotfiles
  sed -i 's/https/ssh/g' /home/mamutal91/.dotfiles/.git/config
  sed -i 's/github/git@github/g' /home/mamutal91/.dotfiles/.git/config
fi
