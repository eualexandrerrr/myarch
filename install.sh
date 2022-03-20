#!/usr/bin/env bash

source colors.sh
read -r -p "${GRE}You username? ${END}" USERNAME
[[ -z $USERNAME ]] && export USERNAME=mamutal91 || export USERNAME=$USERNAME
echo -e "$USERNAME\n"
read -r -p "You hostname? " HOSTNAME
[[ -z $HOSTNAME ]] && export HOSTNAME=nitro5 || export HOSTNAME=$HOSTNAME
echo -e "$HOSTNAME\n"

export DISK_NAME="crypt"

clear

if [[ $USERNAME == mamutal91 ]]; then
  SSD=/dev/nvme0n1 # ssd m2 nvme
  SSD1=/dev/nvme0n1p1 # EFI (boot)
  SSD2=/dev/nvme0n1p2 # cryptswap
  SSD3=/dev/nvme0n1p3 # cryptsystem
  STORAGE_HDD=/dev/sda # hdd"
  askFormatStorage() {
    echo -n "Você deseja formatar o ${STORAGE_HDD} (hdd)? (y/n)? "; read answer
    if [[ $answer != ${answer#[Yy]} ]]; then
      echo -n "Você tem certeza? (y/n)? "; read answer
      if [[ $answer != ${answer#[Yy]} ]]; then
        formatHDD=true
      else
        formatHDD=false
        echo No format ${STORAGE_HDD}
      fi
    else
      echo No format ${STORAGE_HDD}
    fi
  }
else
  echo -e "Specify disks!!!
  Examples:\n\n
  SSD=/dev/nvme0n1 # ssd m2 nvme
  SSD1=/dev/nvme0n1p1 # EFI (boot)
  SSD2=/dev/nvme0n1p2 # cryptswap
  SSD3=/dev/nvme0n1p3 # cryptsystem
  STORAGE_NVME=/dev/sdb # ssd
  STORAGE_HDD=/dev/sda # hdd"
  exit 0
fi

formatStorage() {
  # Format and encrypt the hdd partition 1
  if [[ $formatHDD == true ]]; then
    sgdisk -g --clear \
      --new=1:0:0       --typecode=3:8300 --change-name=1:hdd \
      $STORAGE_HDD
    cryptsetup luksFormat --align-payload=8192 -s 256 -c aes-xts-plain64 $STORAGE_HDD
    if [[ $? -eq 0 ]]; then
      echo "cryptsetup luksFormat SUCCESS ${STORAGE_HDD}"
    else
      echo "cryptsetup luksFormat FAILURE ${STORAGE_HDD}"
      exit 1
    fi
    cryptsetup luksOpen $STORAGE_HDD hdd
    mkfs.btrfs --force --label hdd /dev/mapper/hdd
    cryptsetup luksOpen $STORAGE_HDD hdd
  fi
}
formatStorage

format() {
  # Format storage?
  askFormatStorage

  # Format the drive
  sgdisk --zap-all $SSD
  sgdisk -g --clear \
    --new=1:0:+1GiB   --typecode=1:ef00 --change-name=1:EFI \
    --new=2:0:+8GiB   --typecode=2:8200 --change-name=2:cryptswap \
    --new=3:0:0       --typecode=3:8300 --change-name=3:cryptsystem \
    $SSD
  if [[ $? -eq 0 ]]; then
    echo "sgdisk SUCCESS"
    sleep 5 && clear
  else
    echo "sgdisk FAILURE"
    exit 1
  fi

  # Encrypt the system partition
  cryptsetup luksFormat --align-payload=8192 -s 256 -c aes-xts-plain64 $SSD3
  if [[ $? -eq 0 ]]; then
    echo "Crypt luksFormat SUCCESS"
    sleep 5 && clear
  else
    echo "Crypt luksFormat FAILURE"
    exit 1
  fi
  cryptsetup open $SSD3 $DISK_NAME

  # Enable encrypted swap partition
  cryptsetup open --type plain --key-file /dev/urandom $SSD2 swap
  mkswap -L swap /dev/mapper/swap
  swapon -L swap

  # Format the partitions
  mkfs.fat -F32 -n EFI /dev/disk/by-partlabel/EFI
  mkfs.btrfs --force --label $DISK_NAME /dev/mapper/$DISK_NAME

  # Create btrfs subvolumes
  sleep 10 && clear
  echo -e "Create volumes btrfs\n " #green
  mount -t btrfs LABEL=$DISK_NAME /mnt
  mkdir -p /mnt/{root,home,tmp,.snapshots,boot}
  btrfs subvolume create /mnt/root
  btrfs subvolume create /mnt/home
  btrfs subvolume create /mnt/tmp
  btrfs subvolume create /mnt/.snapshots

  # Mount partitions
  echo -e "\nMount volumes btrfs\n" #green
  umount -R /mnt
  args_btrfs="noatime,compress-force=zstd,commit=120,space_cache=v2,ssd"
  mount -t btrfs -o subvol=root,$args_btrfs LABEL=$DISK_NAME /mnt
  mount -t btrfs -o subvol=home,$args_btrfs LABEL=$DISK_NAME /mnt/home
  mount -t btrfs -o subvol=tmp,$args_btrfs LABEL=$DISK_NAME /mnt/tmp
  mount -t btrfs -o subvol=snapshots,$args_btrfs LABEL=$DISK_NAME /mnt/.snapshots
  mount $SSD1 /mnt/boot

  sleep 20

  # Discover the best mirros to download packages
  pacman -Sy reflector --noconfirm --needed
  reflector --verbose -c BR --protocol https --protocol http --sort rate --save /etc/pacman.d/mirrorlist
  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
  sed -i 's/#UseSyslog/UseSyslog/' /etc/pacman.conf
  sed -i 's/#Color/Color\\\nILoveCandy/' /etc/pacman.conf
  sed -i 's/Color\\/Color/' /etc/pacman.conf
  sed -i 's/#TotalDownload/TotalDownload/' /etc/pacman.conf
  sed -i 's/#CheckSpace/CheckSpace/' /etc/pacman.conf
  sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
  sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 3/g" /etc/pacman.conf

  # Install base and some basic tools
  pacstrap /mnt --noconfirm \
    base base-devel bash-completion \
    linux-lts linux-lts-headers linux linux-headers \
    linux-firmware linux-firmware-whence \
    mkinitcpio pacman-contrib archiso \
    linux-api-headers util-linux util-linux-libs lib32-util-linux \
    btrfs-progs efibootmgr efitools gptfdisk grub grub-btrfs \
    iwd networkmanager dhcpcd sudo nano reflector openssh git curl wget zsh \
    alsa-firmware alsa-utils alsa-plugins pulseaudio pulseaudio-bluetooth pavucontrol \
    sox bluez bluez-libs bluez-tools bluez-utils feh rofi dunst picom \
    stow nano nano-syntax-highlighting neofetch vlc gpicview zsh zsh-syntax-highlighting maim ffmpeg \
    imagemagick slop terminus-font noto-fonts-emoji ttf-dejavu ttf-liberation \
    xorg-server xorg-xrandr xorg-xbacklight xorg-xinit xorg-xprop xorg-server-devel xorg-xsetroot xclip xsel xautolock xorg-xdpyinfo xorg-xinput \
    atom i3-gaps i3lock alacritty thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman telegram-desktop

  # Generate fstab entries
  genfstab -L -p /mnt >> /mnt/etc/fstab
  sed -i "s+LABEL=swap+/dev/mapper/cryptswap+" /mnt/etc/fstab

  # Add cryptab entry
  echo "cryptswap $SSD2 /dev/urandom swap,offset=2048,cipher=aes-xts-plain64,size=256" >> /mnt/etc/crypttab

  # Copy wifi connection
  mkdir -p /mnt/var/lib/iwd
  chmod 700 /mnt/var/lib/iwd
  cp -rf /var/lib/iwd/*.psk /mnt/var/lib/iwd

  # Arch Chroot
  sed -i "2i USERNAME=${USERNAME}" configure.sh
  sed -i "3i HOSTNAME=${HOSTNAME}" configure.sh
  sed -i "4i SSD2=${SSD2}" configure.sh
  sed -i "5i SSD3=${SSD3}" configure.sh
  sed -i "6i STORAGE_HDD=${STORAGE_HDD}" configure.sh
  sed -i "7i DISK_NAME=${DISK_NAME}" configure.sh
  chmod +x configure.sh
  cp -rf configure.sh /mnt
  clear
  sleep 5
  arch-chroot /mnt ./configure.sh
  if [[ $? -eq 0 ]]; then
    echo -e "\n\nFinished SUCCESS\n"
    read -r -p "Reboot now? [Y/n]" confirmReboot
    if [[ ! $confirmReboot =~ ^(n|N) ]]; then
      umount -R /mnt
      reboot
    else
      arch-chroot /mnt
    fi
  else
    echo "configure FAILURE"
    exit 1
  fi
}

recovery() {
  cryptsetup open $SSD3 $DISK_NAME
  cryptsetup open --type plain --key-file /dev/urandom $SSD2 swap
  mkswap -L swap /dev/mapper/swap
  swapon -L swap
  args_btrfs="noatime,compress-force=zstd,commit=120,space_cache=v2,ssd"
  mount -t btrfs -o subvol=root,$args_btrfs LABEL=$DISK_NAME /mnt
  mount -t btrfs -o subvol=home,$args_btrfs LABEL=$DISK_NAME /mnt/home
  mount -t btrfs -o subvol=snapshots,$args_btrfs LABEL=$DISK_NAME /mnt/.snapshots
  mount $SSD1 /mnt/boot
  sleep 5
  arch-chroot /mnt
}

if [[ ${1} == "recovery" ]]; then
  recovery
else
  format
fi
