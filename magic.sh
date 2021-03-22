#!/usr/bin/env bash

function recovery() {
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
  lvcreate -l 100%FREE arch -n home

  mkfs.fat -F32 /dev/sda1
  mkfs.ext4 /dev/mapper/arch-root
  mkfs.ext4 /dev/mapper/arch-home

  mount /dev/mapper/arch-root /mnt
  mkdir -p /mnt/{home,boot,hostlvm}
  mount /dev/mapper/arch-home /mnt/home
  mount /dev/sda1 /mnt/boot

  mount --bind /run/lvm /mnt/hostlvm

  echo "Config zRam"
  modprobe zram
  echo lz4 > /mnt/sys/block/zram0/comp_algorithm
  echo 32G > /mnt/sys/block/zram0/disksize
  mkswap --label zram0 /mnt/dev/zram0
  swapon --priority 100 /mnt/dev/zram0

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

if [ "${1}" = "recovery" ];
then
  recovery
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
