#!/usr/bin/env bash

source colors.sh

clear

read -r -p "${BOL_GRE}You username? ${MAG}enter=${CYA}mamutal91${END}" USERNAME
[[ -z $USERNAME ]] && USERNAME=mamutal91 || USERNAME=$USERNAME
echo -e "  ${YEL}$USERNAME${END}\n"
read -r -p "${BOL_GRE}You hostname? ${MAG}enter=${CYA}odin${END}" HOSTNAME
[[ -z $HOSTNAME ]] && HOSTNAME=odin || HOSTNAME=$HOSTNAME
echo -e "  ${YEL}$HOSTNAME${END}\n"

if [[ $USERNAME == mamutal91 ]]; then
  SSD=/dev/nvme0n1 # ssd m2 nvme
  SSD1=/dev/nvme0n1p1 # EFI (boot)
  SSD2=/dev/nvme0n1p2 # cryptswap
  SSD3=/dev/nvme0n1p3 # cryptsystem
  # Use este
  SSD=/dev/sda # ssd m2
  SSD1=/dev/sda1 # EFI (boot)
  SSD2=/dev/sda2 # cryptswap
  SSD3=/dev/sda3 # cryptsystem
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

formatDrive() {
  echo -e "\n${BOL_GRE}Formatando $SSD ${END}"
  sgdisk --zap-all $SSD
  sgdisk -g --clear \
  --new=1:0:+1GiB --typecode=1:ef00 --change-name=1:EFI \
  --new=2:0:+8GiB --typecode=2:8200 --change-name=2:cryptswap \
  --new=3:0:0   --typecode=3:8300 --change-name=3:cryptsystem \
  $SSD
}

encryptSystem() {
  echo -e "\n${BOL_GRE}Criptografando partição principal - $SSD3 ${END}"
  cryptsetup luksFormat --align-payload=8192 -s 256 -c aes-xts-plain64 $SSD3
}

unlockDisk() {
  echo -e "\n${BOL_GRE}Destravando partição principal - $SSD3 ${END}"
  cryptsetup open /dev/disk/by-partlabel/cryptsystem system
}

unlockSwap() {
  echo -e "\n${BOL_GRE}Destravando partição swap - $SSD2 ${END}"
  cryptsetup open --type plain --key-file /dev/urandom /dev/disk/by-partlabel/cryptswap swap
}

formatSwap() {
  echo -e "\n${BOL_GRE}Formatando e ativando partições swap - $SSD2 ${END}"
  mkswap -L swap /dev/mapper/swap
  swapon -L swap
}

formatPartitions() {
  echo -e "\n${BOL_GRE}Formatando EFI e $SSD${END}"
  mkfs.fat -F32 -n EFI /dev/disk/by-partlabel/EFI
  mkfs.btrfs --force --label system /dev/mapper/system
}

createSubVolumesBtrfs() {
  echo -e "\n${BOL_GRE}Criando volumes ${END}"
  mount -t btrfs LABEL=system /mnt
  btrfs subvolume create /mnt/root
  btrfs subvolume create /mnt/home
  btrfs subvolume create /mnt/snapshots
}

mountPartitions() {
  echo -e "\n${BOL_GRE} volumes ${END}"
  o="defaults,x-mount.mkdir"
  o_btrfs="$o,noatime,compress-force=zstd,commit=120,space_cache=v2,ssd"
  umount -R /mnt
  mount -t btrfs -o subvol=root,$o_btrfs LABEL=system /mnt
  mount -t btrfs -o subvol=home,$o_btrfs LABEL=system /mnt/home
  mount -t btrfs -o subvol=snapshots,$o_btrfs LABEL=system /mnt/snapshots
  mkdir -p /mnt/boot
  mount $SSD1 /mnt/boot
}

reflectorMirrors() {
  pacman -Sy reflector --noconfirm --needed
  reflector --verbose --sort rate -l 5 --save /etc/pacman.d/mirrorlist
  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
  sed -i 's/#UseSyslog/UseSyslog/' /etc/pacman.conf
  sed -i 's/#Color/Color\\\nILoveCandy/' /etc/pacman.conf
  sed -i 's/Color\\/Color/' /etc/pacman.conf
  sed -i 's/#TotalDownload/TotalDownload/' /etc/pacman.conf
  sed -i 's/#CheckSpace/CheckSpace/' /etc/pacman.conf
  sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
  sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 20/g" /etc/pacman.conf
}

pacstrapInstall() {
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
}

genfstabGenerator() {
  genfstab -L -p /mnt >> /mnt/etc/fstab
  sed -i "s+LABEL=swap+/dev/mapper/cryptswap+" /mnt/etc/fstab
}

cryptswapAdd() {
  echo "cryptswap $SSD2 /dev/urandom swap,offset=2048,cipher=aes-xts-plain64,size=256" >> /mnt/etc/crypttab
}

copyWifi() {
  mkdir -p /mnt/var/lib/iwd
  chmod 700 /mnt/var/lib/iwd
  cp -rf /var/lib/iwd/*.psk /mnt/var/lib/iwd
}

chrootPrepare() {
  sed -i "2i USERNAME=${USERNAME}" configure.sh
  sed -i "3i HOSTNAME=${HOSTNAME}" configure.sh
  sed -i "4i SSD2=${SSD2}" configure.sh
  sed -i "5i SSD3=${SSD3}" configure.sh
  chmod +x colors.sh && cp -rf colors.sh /mnt
  chmod +x configure.sh && cp -rf configure.sh /mnt && clear && sleep 5
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
    echo "${BOL_RED}TUDO FALHOU!!!${END}"
    exit 1
  fi
}

recovery() {
  unlockDisk
  unlockSwap
  formatSwap
  mountPartitions
  sleep 5
  arch-chroot /mnt
}

run() {
  formatDrive
  encryptSystem
  unlockDisk
  unlockSwap
  formatSwap
  formatPartitions
  createSubVolumesBtrfs
  mountPartitions
  reflectorMirrors
  pacstrapInstall
  genfstabGenerator
  cryptswapAdd
  copyWifi
  chrootPrepare
}

if [[ ${1} == "recovery" ]]; then
  recovery
else
  echo -e "\n${BOL_BLU}Iniciando instalação do ArchLinux${END}"
  run "$@" || echo "$@ falhou" && exit
fi
