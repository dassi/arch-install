#!/bin/sh

# Assuming:
# - UEFI boot system
# 
# Check if you have UEFI system: cat /sys/firmware/efi/fw_platform_size

# TBD: Use a text displayer for each step to show instructions and let user do it on the shell
#
#

echo "Not a real script, go through the steps manually"
exit

# Arch install Andreas Brodbeck
# See: https://gilyes.com/Installing-Arch-Linux-with-LVM/
# See: https://www.youtube.com/watch?v=nCc_4fSYzRA
# See: https://computingforgeeks.com/install-arch-linux-with-lvm-on-uefi-system/

# login into a live boot as root

loadkeys de_CH-latin1
timedatectl set-ntp true

# find the device to install. E.g. sda
# or fdisk -l
lsblk

# Eine 512MB boot partition & 1 grosse physische Rest-Partition erstellen mit fdisk:
#
# p for print the list
#
# Optional to delete existing: d
#
# n (to add a new partition)
# p (for primary partition)
# 1 (default partition number)
# (accept default start)
# boot: +512M

# Do again for the big LVM partition
# Then:
# n
# p (primary)
# 2 (or default)
# (accept default start)
# (accept default end)
# t (to change partition type)
# 8e or "lvm" (for LVM partition)
#
# p (to verify)
# w (save and quit)
fdisk /dev/sdX

# LVM aufsetzen in der zweiten Partition. LVs erstellen für root und home
pvcreate /dev/sdX2
vgcreate lvm-vg1 /dev/sdX2

# DONT. boot is native partition. lvcreate -L 1G lvm-vg1 -n lv-boot

# Create root partition, for the linux system 
lvcreate -L 30G lvm-vg1 -n lv-root

# Keine swap partition? Wir verwenden ein swap file statt partition

# Create the remaining drive. Use 50% of the free space, keep some space for snapshots
lvcreate -l 50%FREE lvm-vg1 -n lv-home



# UEFI fat32 statt ext4 auf boot wenn UEFI:
mkfs.fat -F32 /dev/sda1
fatlabel /dev/sda1 BOOT
# Bei legacy BIOS keine boot partition
mkfs.ext4 -L ROOT /dev/lvm-vg1/lv-root
mkfs.ext4 -L HOME /dev/lvm-vg1/lv-home
#mkswap -L SWAP /dev/sdaY

# Echte Mountpoints vorbereiten auf dem noch live system:
# BOOT nur bei UEFI
mount /dev/disk/by-label/ROOT /mnt
mount --mkdir /dev/disk/by-label/BOOT /mnt/boot
mount --mkdir /dev/disk/by-label/HOME /mnt/home

# Order the sources to geographic distance. Nearest first.
# Europe seems to be at the top, so not to bad. Pre sorted by reflector.
# vim /etc/pacman.d/mirrorlist

# Install base arch system
# Bei Problemen mit package integrity:
pacman -Sy archlinux-keyring
pacstrap /mnt base base-devel linux linux-firmware

# Install base system, some more essentials for the start
pacstrap /mnt efibootmgr vim lvm2 networkmanager grub os-prober man-db man-pages openssh


# https://wiki.archlinux.org/title/Swap#Swap_file
# swapfile, replace the 512MB to your size
dd if=/dev/zero of=/mnt/swapfile bs=1M count=512 status=progress
chmod 0600 /mnt/swapfile
mkswap -U clear /mnt/swapfile
swapon /mnt/swapfile

# fstab generation
genfstab -U /mnt >> /mnt/etc/fstab

# chroot
arch-chroot /mnt



# Set timezone
ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime
hwclock --systohc
vim /etc/locale.gen
# ... and uncomment the used ones, typically de_CH.UTF-8 and en_US.UTF-8
locale-gen

vim /etc/locale.conf
# Inhalt:
# LANG=en_US.UTF-8
# LC_COLLATE=C.UTF-8

# Inhalt: "KEYMAP=de_CH-latin1"
vim /etc/vconsole.conf

# Hostnamen in File schreiben
vim /etc/hostname

# Evt. weitere Netzwerk Konfiguration https://wiki.archlinux.org/title/Network_configuration
# vim /etc/hosts
# 127.0.0.1 localhost
# ::1 localhost
# 127.0.0.1 hostnameXY.localdomain hostnameXY

vim /etc/mkinitcpio.conf
# Dort drin lvm2 ergänzen:
# HOOKS=".... lvm2 filesystems..."

mkinitcpio -P

# root password
passwd


# Grub
# https://wiki.archlinux.org/title/GRUB

# Falls windows dual boot:
# In /etc/default/grub unkommentieren:
# GRUB_DISABLE_OS_PROBER=false
# TBD: Grosse Schrift bei hidpi, Windows Partition zuerst mounten dann wirds erkannt
# GRUB_GFXMODE=1024x768x32
# GRUB_GFXPAYLOAD_LINUX=keep

# https://wiki.archlinux.org/title/Microcode
pacman -S intel-ucode

# For BIOS: grub-install --target=i386-pc /dev/sdX
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg




useradd -m -g wheel dassi
passwd dassi

# Uncomment the line for group "wheel"
visudo

# erst  Nach reboot?
systemctl enable --now NetworkManager

# exit chroot environment
exit                           

# Hm, says "target busy" ? Evt. swapoff vorher?
umount -R /mnt

# reboot and remove your USB stick
reboot


# dann: desktop install script ...
# falls wifi: evt mit nmtui netzerk/wifi aktivieren
curl -O https://github.com/dassi/arch-install/02_arch_install_desktop.sh
bash 02_arch_install_desktop.sh
