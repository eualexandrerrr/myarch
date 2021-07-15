# ~/myarch

![arch](https://github.com/mamutal91/myarch/raw/master/images/arch.png)

## How to use?

1. Download the latest iso from the [**ArchLinux website**](https://archlinux.org/download/)

2. Create the image
```bash
dd if=archlinux-2021.07.01-x86_64.iso of=/dev/sdb status=progress && sync
```
3. You need to [**disable UEFI secure boot**](https://www.google.com/search?q=how+to+disable+uefi+secure+boot+bios&sxsrf=ALeKk00nf_nHTJhKj9AFnGoqWU_jUnoh2Q%3A1626391533582&ei=7cPwYImaItnd1sQP_4yCoAM&oq=how+to+disable+uefi+secure+boot+bios&gs_lcp=Cgdnd3Mtd2l6EAMyBggAEBYQHjIGCAAQFhAeMgYIABAWEB4yBggAEBYQHjIGCAAQFhAeOgcIIxCwAxAnOgcIABBHELADOgQIIxAnOggIABCxAxCDAToFCAAQsQM6AggAOg4ILhCxAxCDARDHARCvAToICC4QsQMQgwE6BAgAEEM6BQguELEDOgIILjoFCAAQywE6BggAEA0QHkoECEEYAFDRFFimVWC6VmgEcAJ4AYABxwGIAcwgkgEEMC4zMZgBAKABAaoBB2d3cy13aXrIAQnAAQE&sclient=gws-wiz&ved=0ahUKEwjJxP7MnObxAhXZrpUCHX-GADQQ4dUDCA4&uact=5) in your bios
4. Reboot and boot the pendrive
5. Start Arch Linux install

![menu](https://github.com/mamutal91/myarch/raw/master/images/menu.png)

6. You should be seeing something like the image below.

![tty](https://github.com/mamutal91/myarch/raw/master/images/tty.png)

## Installation steps
#### Keyboard mapping

1. If you don't know, run the first command to list the available options
```bash
localectl list-keymaps
```

2. Load your keyboard mapping
```bash
loadkeys br-abnt2
```

#### Connect wifi (if you are using network cable, skip this part)

1. Discover your wireless interface
```bash
iwctl device list
```

 | Name | Address | Powered | Adapter | Mode
 |--|--|--|--|--|
 | wlan0 | 80:30:49:0c:be:9b | on | phy0 | station |

2. Scan nearby networks
```bash
iwctl station wlan0 scan
```

3. Connect
```bash
iwctl station wlan0 connect 'Mamut 5GHz'
```

#### Install!

1. Install git
```bash
pacman -Sy git --noconfirm
```

2. Clone this repository and enter the folder
```bash
git clone https://github.com/mamutal91/myarch
cd myarch
```

3. Run script
```bash
./install.sh
```

## Final considerations
This installation does not provide a graphical interface, but if you want you can try [**my dotfiles**](https://github.com/mamutal91/dotfiles) or search for other interface installation tutorials.
