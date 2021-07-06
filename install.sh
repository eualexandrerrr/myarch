#!/usr/bin/env bash

if [[ ${1} == qemu ]]; then
  DISK=/dev/sda # nvme
  DISK1=/dev/sda1 # EFI (boot)
  DISK2=/dev/sda2 # cryptswap
  DISK3=/dev/sda3 # cryptsystem
  HDD=/dev/sda # storage
else
  DISK=/dev/nvme0n1 # nvme
  DISK1=/dev/nvme0n1p1 # EFI (boot)
  DISK2=/dev/nvme0n1p2 # cryptswap
  DISK3=/dev/nvme0n1p3 # cryptsystem
  HDD=/dev/sda # storage
fi

HOSTNAME=odin
USERNAME=mamutal91

[[ $USERNAME == mamutal91 ]] && git config --global user.email "mamutal91@gmail.com" && git config --global user.name "Alexandre Rangel"

if [[ ${1} == recovery ]]; then
  cryptsetup open $DISK3 system
  cryptsetup open --type plain --key-file /dev/urandom $DISK2 swap
  mkswap -L swap /dev/mapper/swap
  swapon -L swap
  o=defaults,x-mount.mkdir
  o_btrfs=$o,compress=lzo,ssd,noatime
  mount -t btrfs -o subvol=root,$o_btrfs LABEL=system /mnt
  mount -t btrfs -o subvol=home,$o_btrfs LABEL=system /mnt/home
  mount -t btrfs -o subvol=snapshots,$o_btrfs LABEL=system /mnt/.snapshots
  mount $DISK1 /mnt/boot
  sleep 5
  arch-chroot
else
  # Format the drive
  sgdisk --clear \
    --new=1:0:+550MiB --typecode=1:ef00 --change-name=1:EFI \
    --new=2:0:+4GiB   --typecode=2:8200 --change-name=2:cryptswap \
    --new=3:0:0       --typecode=3:8300 --change-name=3:cryptsystem \
    $DISK
    if [[ $? -eq 0 ]]; then
      echo "sgdisk SUCCESS"
    else
      echo "sgdisk FAILURE"
      exit 1
    fi

  # Encrypt the system partition
  cryptsetup luksFormat --align-payload=8192 -s 256 -c aes-xts-plain64 $DISK3
  if [[ $? -eq 0 ]]; then
    echo "cryptsetup luksFormat SUCCESS"
  else
    echo "cryptsetup luksFormat FAILURE"
    exit 1
  fi
  cryptsetup open $DISK3 system

  # Enable encrypted swap partition
  cryptsetup open --type plain --key-file /dev/urandom $DISK2 swap
  mkswap -L swap /dev/mapper/swap
  swapon -L swap

  # Format the partitions
  mkfs.fat -F32 -n EFI /dev/disk/by-partlabel/EFI
  mkfs.btrfs --force --label system /dev/mapper/system

  # Create btrfs subvolumes
  mount -t btrfs LABEL=system /mnt
  btrfs subvolume create /mnt/root
  btrfs subvolume create /mnt/home
  btrfs subvolume create /mnt/snapshots

  # Mount partitions
  o=defaults,x-mount.mkdir
  o_btrfs=$o,compress=lzo,ssd,noatime
  umount -R /mnt
  mount -t btrfs -o subvol=root,$o_btrfs LABEL=system /mnt
  mount -t btrfs -o subvol=home,$o_btrfs LABEL=system /mnt/home
  mount -t btrfs -o subvol=snapshots,$o_btrfs LABEL=system /mnt/.snapshots
  mkdir /mnt/boot
  mount $DISK1 /mnt/boot

  # Discover the best mirros to download packages
  reflector --verbose --country 'Brazil' --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
  sed -i "s/#Color/Color/g" /etc/pacman.conf
  sed -i "s/#UseSyslog/UseSyslog/g" /etc/pacman.conf
  sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
  sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 10/g" /etc/pacman.conf

  # Install base system and some basic tools
  pacstrap /mnt --noconfirm \
    base base-devel bash-completion linux linux-headers linux-firmware mkinitcpio pacman-contrib \
    btrfs-progs efibootmgr efitools gptfdisk grub grub-btrfs \
    iwd networkmanager dhcpcd sudo grub nano git reflector wget openssh zsh git curl wget \
    nvidia nvidia-utils nvidia-settings nvidia-utils nvidia-dkms opencl-nvidia

  # Generate fstab entries
  genfstab -L -p /mnt >> /mnt/etc/fstab
  sed -i "s+LABEL=swap+/dev/mapper/cryptswap+" /mnt/etc/fstab

  # Add cryptab entry
  echo "cryptswap $DISK2 /dev/urandom swap,offset=2048,cipher=aes-xts-plain64,size=256" >> /mnt/etc/crypttab

  # Arch Chroot
  arch-chroot /mnt useradd -m -G wheel -s /bin/bash $USERNAME
  arch-chroot /mnt sed -i "s/root ALL=(ALL) ALL/root ALL=(ALL) NOPASSWD: ALL\n$USERNAME ALL=(ALL) NOPASSWD:ALL/g" /etc/sudoers
  arch-chroot /mnt mkdir -p /home/$USERNAME
  arch-chroot /mnt echo $HOSTNAME > /etc/hostname
  arch-chroot /mnt passwd root
  arch-chroot /mnt passwd $USERNAME

  chmod +x pos-install.sh && cp -rf pos-install.sh /mnt && clear
  arch-chroot /mnt ./pos-install.sh
  if [[ $? -eq 0 ]]; then
    umount -R /mnt
    echo "Finished SUCCESS\n"
    read -r -p "Reboot now? [Y/n]" confirmReboot
    if [[ ! $confirmReboot =~ ^(n|N) ]]; then
      reboot
    fi
  else
    echo "pos-install FAILURE"
    exit 1
  fi
fi
