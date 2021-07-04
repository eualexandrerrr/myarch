#!/usr/bin/env bash

read -r -p "You username? " username
[[ -z $username ]] && username=mamutal91 || username=$username
echo -e "$username\n"
read -r -p "You hostname? " hostname
[[ -z $hostname ]] && hostname=odin || hostname=$hostname
echo -e "$hostname\n"
read -r -p "You password default? " password
echo -e "$password\n"

# Config pacman
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "s/#Color/Color/g" /etc/pacman.conf
sed -i "s/#UseSyslog/UseSyslog/g" /etc/pacman.conf
sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 10/g" /etc/pacman.conf

if [[ ${1} == recovery ]]; then
  echo "Unlock and mount /dev/nvme0n1p2"
  echo $password | cryptsetup luksOpen /dev/nvme0n1p2 lvm
  sleep 30
  echo "Mounting partitions... (30 seconds)"
  mount /dev/mapper/arch-root /mnt
  mount /dev/nvme0n1p1 /mnt/boot
  arch-chroot /mnt
else
  echo "Formatting /dev/nvme0n1p2"
  echo YES | cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 --use-random -i 100 /dev/nvme0n1p2
  echo $password | cryptsetup luksOpen /dev/nvme0n1p2 lvm

  if [[ ${1} == storage ]]; then
    echo YES | cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 --use-random -i 100 /dev/sda1
    echo $password | cryptsetup luksOpen /dev/sda1 storage
    mkfs.ext4 /dev/mapper/storage
    echo $password | cryptsetup luksOpen /dev/sda1 storage
  fi

  pvcreate /dev/mapper/lvm
  vgcreate arch /dev/mapper/lvm

  lvcreate -L 25G arch -n root
  lvcreate -L 8G arch -n swap
  lvcreate -l 100%FREE arch -n home

  mkfs.fat -F32 /dev/nvme0n1p1
  mkfs.ext4 /dev/mapper/arch-root
  mkswap /dev/mapper/arch-swap
  mkfs.ext4 /dev/mapper/arch-home

  mount /dev/mapper/arch-root /mnt
  mkdir -p /mnt/{home,boot,hostlvm}
  mount /dev/mapper/arch-home /mnt/home
  mount /dev/nvme0n1p1 /mnt/boot
  sudo swapon -va

  mount --bind /run/lvm /mnt/hostlvm

  echo "Getting better mirrors"
  pacman -Sy reflector --noconfirm
  reflector -c Brazil --sort score --save /etc/pacman.d/mirrorlist

  pacstrap /mnt --noconfirm \
    base base-devel bash-completion \
    linux linux-headers linux-firmware \
    lvm2 mkinitcpio \
    pacman-contrib \
    iwd networkmanager dhcpcd sudo grub efibootmgr nano git reflector wget openssh \
    nvidia nvidia-utils nvidia-settings nvidia-utils nvidia-dkms opencl-nvidia

  genfstab -U /mnt >> /mnt/etc/fstab

  echo "Starting arch-chroot..."
  cp -rf configSystem.sh /mnt
  arch-chroot /mnt ./configSystem.sh ${username} ${hostname} ${password}
fi

# Reboot
if [[ $? == "0" ]]; then
  echo -e "\nFinished successfully."
  read -r -p "Reboot now? [Y/n]" confirmReboot
  if [[ ! $confirmReboot =~ ^(n|N)   ]]; then
    reboot
  fi
fi
