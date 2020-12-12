#!/usr/bin/env bash
# github.com/mamutal91

source files/colors.sh

mkfs.fat -F32 /dev/sda1

cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 --use-random -i 100 /dev/sda2
#cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 --use-random -i 100 /dev/sda3

cryptsetup luksOpen /dev/sda2 lvm
#cryptsetup luksOpen /dev/sda3 storage

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

pacstrap -i /mnt base base-devel bash-completion linux linux-headers linux-firmware mkinitcpio lvm2 --noconfirm

genfstab -U /mnt >> /mnt/etc/fstab

# Setup new system
rm -rf /mnt/archlinux-installer && mkdir /mnt/archlinux-installer
cp -r ./* /mnt/archlinux-installer/
arch-chroot /mnt /archlinux-installer/setup.sh
