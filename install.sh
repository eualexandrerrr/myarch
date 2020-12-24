#!/usr/bin/env bash
# github.com/mamutal91

#if [ ${1} = "open" ]; then
#  cryptsetup luksOpen /dev/sda2 lvm
#  mount /dev/mapper/arch-root /mnt
#  mount /dev/sda1 /mnt/boot
#  arch-chroot /mnt
#else

mkfs.fat -F32 /dev/sda1

cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 --use-random -i 100 /dev/sda2
#cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 --use-random -i 100 /dev/sda3

cryptsetup luksOpen /dev/sda2 lvm
#cryptsetup luksOpen /dev/sda3 storage
#mkfs.ext4 /dev/mapper/storage

pvcreate /dev/mapper/lvm
vgcreate arch /dev/mapper/lvm

lvcreate -L 100G arch -n root
lvcreate -L 8G arch -n swap
lvcreate -l 100%FREE arch -n home

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
  base base-devel
  bash-completion
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

# Setup new system
cp -r setup.sh /mnt
arch-chroot /mnt ./setup.sh

#if [[ "$?" == "0" ]]; then
#  echo "Finished successfully."
#  read -r -p "Reboot now? [Y/n]" confirm
#  if [[ ! "$confirm" =~ ^(n|N) ]]; then
#    reboot
#  fi
#fi
#fi
