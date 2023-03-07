SSD=/dev/sda # ssd m2
SSD1=/dev/sda1 # EFI (boot)
SSD2=/dev/sda2 # cryptswap
SSD3=/dev/sda3 # cryptsystem


  sgdisk --zap-all $SSD
  sgdisk -g --clear \
  --new=1:0:+1GiB --typecode=1:ef00 --change-name=1:EFI \
  --new=2:0:+8GiB --typecode=2:8200 --change-name=2:cryptswap \
  --new=3:0:0   --typecode=3:8300 --change-name=3:cryptsystem \
  $SSD
