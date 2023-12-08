#!/bin/sh

# Assuming:
# - UEFI boot system (If old BIOS see comments on each section)
# 
# Check if you have UEFI system: cat /sys/firmware/efi/fw_platform_size


echo "Not a real script, go through the steps manually"
exit

# Arch install Andreas Brodbeck
# See: https://gilyes.com/Installing-Arch-Linux-with-LVM/
# See: https://www.youtube.com/watch?v=nCc_4fSYzRA
# See: https://computingforgeeks.com/install-arch-linux-with-lvm-on-uefi-system/

# login into a live boot as root

# Set the correct keyboard layout, so you can type correctly
loadkeys de_CH-latin1

# If system clock is wrong, then sync with internet time
timedatectl set-ntp true


#####################
# Creating the disks
#####################
# - We create a simple partition for the boot partition, and the rest for LVM.
# - For swap we use a file, not a disk
# - (BIOS: boot partition not needed)

# find the device to install to. E.g. "sda"
# or fdisk -l
lsblk

# Create a 512MB boot partition & 1 big physical rest partition with fdisk:
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

# Add the second partition as a physical volume to LVM.
pvcreate /dev/sdX2

# Create default volume group, called it for example "lvm-vg1"
vgcreate lvm-vg1 /dev/sdX2

# Create logical volume "root" partition, for the linux system. Usually around 30GB is enough (for linux and apps)
lvcreate -L 30G lvm-vg1 -n lv-root

# Create logical volume "home" partition, with the remaining drive. Use 50% of the free space, keep some space for LVM snapshots
lvcreate -l 50%FREE lvm-vg1 -n lv-home


###############################
# Creating the filesystems
###############################

# UEFI: Needs to be fat32 on boot partition
# (If BIOS: Skip, no boot partition needed)
mkfs.fat -F32 /dev/sda1
fatlabel /dev/sda1 BOOT
mkfs.ext4 -L ROOT /dev/lvm-vg1/lv-root
mkfs.ext4 -L HOME /dev/lvm-vg1/lv-home

# Mount the fresh disks into the live filesystem, so we can write to them and install arch
# (BIOS: Skip boot partition)
mount /dev/disk/by-label/ROOT /mnt
mount --mkdir /dev/disk/by-label/BOOT /mnt/boot
mount --mkdir /dev/disk/by-label/HOME /mnt/home


############################
# Installing packages
############################


# OPTIONAL: Order the sources to geographic distance. Nearest first.
# Europe seems to be at the top, so not to bad. Pre sorted by reflector.
# vim /etc/pacman.d/mirrorlist

# I had some package integrity errors, due to outdated keys. So we update the keyring anyway:
pacman -Sy archlinux-keyring

# Install base arch system
pacstrap /mnt base base-devel linux linux-firmware

# Install some more essentials for the start
pacstrap /mnt efibootmgr vim lvm2 networkmanager grub os-prober man-db man-pages openssh


#########################
# Create swap file
#########################

# See https://wiki.archlinux.org/title/Swap#Swap_file
# swapfile, replace the 512MB to your approx. size.
# Swapfile will grow, if needed.
dd if=/dev/zero of=/mnt/swapfile bs=1M count=512 status=progress
chmod 0600 /mnt/swapfile
mkswap -U clear /mnt/swapfile
swapon /mnt/swapfile


########################
# Configuration
########################

# fstab generation
genfstab -U /mnt >> /mnt/etc/fstab

# chroot into the mounted root partition
arch-chroot /mnt

# Set timezone
ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime

# Set hardware clock
hwclock --systohc

# Activate and create your needed locales: uncomment the used ones, typically de_CH.UTF-8 and en_US.UTF-8
vim /etc/locale.gen
locale-gen

# Config your default locale.
# File content:
# LANG=en_US.UTF-8
# LC_COLLATE=C.UTF-8
vim /etc/locale.conf

# Config your virtual console. At least set the correct keyboard layout.
# File content: "KEYMAP=de_CH-latin1"
vim /etc/vconsole.conf

# Config your hostname
vim /etc/hostname

# OPTIONAL: Config network
# See also https://wiki.archlinux.org/title/Network_configuration for further network configs
# vim /etc/hosts
# 127.0.0.1 localhost
# ::1 localhost
# 127.0.0.1 hostnameXY.localdomain hostnameXY

# Config linux startup
# Activate lvm2 support, add lvm2 kernelmodule in HOOKS line:
# HOOKS=".... lvm2 filesystems..."
vim /etc/mkinitcpio.conf
mkinitcpio -P

# Set your root password
passwd

# Config default user
useradd -m -g wheel dassi
passwd dassi

# Config sudo
# Uncomment the line for group "wheel"
visudo

# TODO: Only possible after reboot and not in chroot?
systemctl enable --now NetworkManager


####################
# Grub boot loader
####################


# See https://wiki.archlinux.org/title/GRUB

# If windows dual boot:
# In /etc/default/grub uncomment:
# GRUB_DISABLE_OS_PROBER=false
# TBD: Grosse Schrift bei hidpi, Windows Partition zuerst mounten dann wirds erkannt
# GRUB_GFXMODE=1024x768x32
# GRUB_GFXPAYLOAD_LINUX=keep

# Add microcode for CPU
# TODO: Why do we need this here and not later?
# https://wiki.archlinux.org/title/Microcode
pacman -S intel-ucode

# Install grub
# (BIOS: grub-install --target=i386-pc /dev/sdX)
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg


###################
# Reboot
###################

# exit chroot environment
exit                           

# Unmount
swapoff /mnt/swapfile
umount -R /mnt

# reboot and remove your USB stick
reboot

# Maybe need to start NetworkManager:
systemctl enable --now NetworkManager

# Then: desktop install script ...
# If wifi: use nmtui to activate wifi network
curl -O https://github.com/dassi/arch-install/02_arch_install_desktop.sh
bash 02_arch_install_desktop.sh
