#!/usr/bin/env bash

function boot() {
  cryptsetup luksOpen /dev/sda2 lvm
  wait
  mount /dev/mapper/arch-root /mnt
  wait
  arch-chroot /mnt
}

function format() {

  echo "Formatting /dev/sda2"
  cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 --use-random -i 100 /dev/sda2
  cryptsetup luksOpen /dev/sda2 lvm

  pvcreate /dev/mapper/lvm
  vgcreate arch /dev/mapper/lvm

  lvcreate -L 25G arch -n root
  lvcreate -L 8G arch -n swap
  lvcreate -l 100%FREE arch -n home

  mkfs.fat -F32 /dev/sda1
  mkfs.ext4 /dev/mapper/arch-root
  mkfs.ext4 /dev/mapper/arch-home
  mkswap /dev/mapper/arch-swap

  mount /dev/mapper/arch-root /mnt
  mkdir /mnt/home
  mkdir /mnt/boot
  mkdir -p /mnt/media/storage
  mkdir /mnt/hostlvm

  mount /dev/mapper/arch-home /mnt/home
  mount /dev/sda1 /mnt/boot

  swapon /dev/mapper/arch-swap
  mount --bind /run/lvm /mnt/hostlvm

  readonly PACKAGES=(
    base base-devel bash-completion
    linux linux-headers linux-firmware
    lvm2
    mkinitcpio
    pacman-contrib
    iwd networkmanager dhcpcd sudo efibootmgr grub nano git
  )

  for i in "${PACKAGES[@]}"; do
    pacstrap /mnt ${i} --noconfirm
  done

  genfstab -U /mnt >> /mnt/etc/fstab

  # setup new system
  wget https://raw.githubusercontent.com/mamutal91/myarch/master/setup.sh
  chmod +x setup.sh
  cp -r setup.sh /mnt
  arch-chroot /mnt ./setup.sh
}

if [ "${1}" = "boot" ];
then
  boot
else
  format
fi

# reboot
if [[ "$?" == "0" ]]; then
  echo "Finished successfully."
  read -r -p "Reboot now? [Y/n]" confirm
  if [[ ! "$confirm" =~ ^(n|N) ]]; then
    reboot
  fi
fi
