#!/usr/bin/env bash

read -r -p "You username? " USERNAME
[[ -z $USERNAME ]] && USERNAME=mamutal91 || USERNAME=$USERNAME
echo -e "$USERNAME\n"
read -r -p "You hostname? " HOSTNAME
[[ -z $HOSTNAME ]] && HOSTNAME=odin || HOSTNAME=$HOSTNAME
echo -e "$HOSTNAME\n"

clear

if [[ $USERNAME == mamutal91 ]]; then
  DISK=/dev/sdb # ssd m2 sata
  DISK1=/dev/sdb1 # EFI (boot)
  DISK2=/dev/sdb2 # cryptswap
  DISK3=/dev/sdb3 # cryptsystem
  STORAGE1=/dev/nvme0n1 # storage
  STORAGE2=/dev/sda # storage hdd
  echo -n "Você deseja formatar o storage ${STORAGE1}? (y/n)? "; read answer
  if [[ $answer != ${answer#[Yy]} ]]; then
    echo -n "Você tem certeza? (y/n)? "; read answer
    if [[ $answer != ${answer#[Yy]} ]]; then
      formatStorage=true
    else
      echo No format ${STORAGE1}
    fi
  else
    echo No format ${STORAGE1}
  fi
else
  DISK=/dev/nvme0n1 # ssd m2 nvme
  DISK1=/dev/nvme0n1p1 # EFI (boot)
  DISK2=/dev/nvme0n1p2 # cryptswap
  DISK3=/dev/nvme0n1p3 # cryptsystem
  STORAGE1=/dev/sdb # storage
  STORAGE2=/dev/sda # storage hdd
fi

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
  arch-chroot /mnt
else
  # Format and encrypt the storage partition
  if [[ $formatStorage == true ]]; then
    sgdisk -g --clear \
      --new=1:0:0       --typecode=3:8300 --change-name=1:storage \
      $STORAGE1
    cryptsetup luksFormat --align-payload=8192 -s 256 -c aes-xts-plain64 $STORAGE1
    if [[ $? -eq 0 ]]; then
      echo "cryptsetup luksFormat SUCCESS ${STORAGE1}"
    else
      echo "cryptsetup luksFormat FAILURE ${STORAGE1}"
      exit 1
    fi
    cryptsetup luksOpen $STORAGE1 storage
    mkfs.btrfs --force --label storage /dev/mapper/storage
    cryptsetup luksOpen $STORAGE1 storage
  fi

  # Format the drive
  sgdisk -g --clear \
    --new=1:0:+1GiB   --typecode=1:ef00 --change-name=1:EFI \
    --new=2:0:+16GiB  --typecode=2:8200 --change-name=2:cryptswap \
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
  sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 100/g" /etc/pacman.conf

  # Install base system and some basic tools
  pacstrap /mnt --noconfirm \
    base base-devel bash-completion linux-lts linux-lts-headers linux linux-headers linux-firmware mkinitcpio pacman-contrib \
    btrfs-progs efibootmgr efitools gptfdisk grub grub-btrfs \
    iwd networkmanager dhcpcd sudo grub nano git reflector wget openssh zsh git curl wget

  # Generate fstab entries
  genfstab -L -p /mnt >> /mnt/etc/fstab
  sed -i "s+LABEL=swap+/dev/mapper/cryptswap+" /mnt/etc/fstab

  # Add cryptab entry
  echo "cryptswap $DISK2 /dev/urandom swap,offset=2048,cipher=aes-xts-plain64,size=256" >> /mnt/etc/crypttab

  # Copy wifi connection to the system
  mkdir -p /mnt/var/lib/iwd
  chmod 700 /mnt/var/lib/iwd
  cp -rf /var/lib/iwd/*.psk /mnt/var/lib/iwd

  # Arch Chroot
  sed -i "2i USERNAME=${USERNAME}" pos-install.sh
  sed -i "3i HOSTNAME=${HOSTNAME}" pos-install.sh
  sed -i "4i DISK2=${DISK2}" pos-install.sh
  sed -i "5i DISK3=${DISK3}" pos-install.sh
  sed -i "6i STORAGE=${STORAGE1}" pos-install.sh
  chmod +x pos-install.sh && cp -rf pos-install.sh /mnt && clear
  arch-chroot /mnt ./pos-install.sh
  if [[ $? -eq 0 ]]; then
    umount -R /mnt
    echo -e "\n\nFinished SUCCESS\n"
    read -r -p "Reboot now? [Y/n]" confirmReboot
    if [[ ! $confirmReboot =~ ^(n|N) ]]; then
      reboot
    fi
  else
    echo "pos-install FAILURE"
    exit 1
  fi
fi
