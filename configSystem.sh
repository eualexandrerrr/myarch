

USER=mamutal91
HOST=odin

echo "#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*"
echo "Starting system configuration..."

ln -s /hostlvm /run/lvm

echo "Config pacman"
reflector -c Brazil --sort score --save /etc/pacman.d/mirrorlist
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "s/#Color/Color/g" /etc/pacman.conf
sed -i "s/#TotalDownload/TotalDownload/g" /etc/pacman.conf

echo "Config mkinitpcio"
sed -i "s/block/block encrypt lvm2/g" /etc/mkinitcpio.conf

mkinitcpio -P

echo "Config sudoers"
sed -i "s/root ALL=(ALL) ALL/root ALL=(ALL) NOPASSWD: ALL\n$USER ALL=(ALL) NOPASSWD:ALL/g" /etc/sudoers

# systemd
sed -i "s/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g" /etc/systemd/logind.conf
sed -i "s/#NAutoVTs=6/NAutoVTs=6/g" /etc/systemd/logind.conf


echo "Config grub"
UUID=$(blkid /dev/sda2 | awk -F '"' '{print $2}')

bootctl install

mkdir -p /boot/loader/entries

echo "title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options cryptdevice=UUID=\"$UUID\":cryptroot:allow-discards root=/dev/mapper/arch-root rw" > /boot/loader/entries/arch.conf
echo "default arch.conf" >> /boot/loader/loader.conf

sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash acpi_backlight=vendor acpi_osi=Linux mitigations=off"/g' /etc/default/grub
sed -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID='$UUID':lvm"/g' /etc/default/grub
sed -i "s/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g" /etc/default/grub
sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "Add my user"
useradd -m -G wheel -s /bin/bash $USER
mkdir -p /home/$USER

if [[ $USER = "mamutal91" ]]; then
  git clone https://github.com/mamutal91/dotfiles /home/$USER/.dotfiles
fi

echo "Set locale, zone and keymap console"
echo KEYMAP=br-abnt2 > /etc/vconsole.conf
sed -i "s/#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/g" /etc/locale.gen
sed -i "s/#pt_BR ISO-8859-1/pt_BR ISO-8859-1/g" /etc/locale.gen
echo LANG=pt_BR.UTF-8 > /etc/locale.conf
sudo ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
locale-gen

echo $HOST > /etc/hostname

systemctl disable NetworkManager
systemctl enable dhcpcd
systemctl enable iwd

echo "Set passwords"
passwd $USER
passwd root
