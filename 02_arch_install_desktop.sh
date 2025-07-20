#!/bin/sh

# ====================================================
# Linux provisioning script.
# Run as root.
# Inspired and taken from LARBS (Luke Smith).
# Made to be rerun.
# Keep me up to date.
#
# TBD: Automatically save a list of installed packages, instead of csv list in here.
# Use: pacman -Qent
#

set -e

#dotfilesrepo="https://github.com/dassi/dotfiles.git"
username="dassi"

# Directory, where the git repositories for compiling will be stored
repodir="/home/$username/.local/src"

#TAG,NAME IN REPO (or git url),PURPOSE (should be a verb phrase to sound right while installing)
apps=$(cat packages_pre.csv packages.csv)

# Remark: Get a list of explicitly installed packages on the system, first from standard repos, then from foreign repos (AUR):
# pacman --quiet -Qent
# pacman --quiet -Qemt
# pacman --quiet -Qemt | while read -r pkg; do pacman -Qi "$pkg" | grep -E 'Name|Description' | awk 'BEGIN {FS=" : "} {print "\"" $2 "\""}' | paste -d ',' - -; done 
# See create_package_list.sh

installPkg(){
    # --noconfirm
		pacman --needed -S $@
}

# Installing from AUR
installPkgAur() {
#		echo "$aurinstalled" | grep -q "^$1$" && return
# --noconfirm
		sudo -u $username yay --aur -S --needed $@

}

installAurhelper() {
		# Should be run after repodir is created and var is set.
		sudo -u $username mkdir -p "$repodir/yay-bin"
		pushd "$repodir/yay-bin"

		sudo -u $username git clone --depth 1 "https://aur.archlinux.org/yay-bin.git" "$repodir/yay-bin" >/dev/null 2>&1 ||
				{ sudo -u $username git pull --force origin master;}

		sudo -u $username makepkg --noconfirm -si >/dev/null 2>&1
		popd
}


# installGitMake() {
# 		progname="$(basename "$1" .git)"
# 		dir="$repodir/$progname"
# 		if [ -d "$dir" ]; then
# 				pushd "$dir"
# 				#sudo -u $username git pull --force origin master;
# 				sudo -u $username git pull --force origin;
# 		else
# 				sudo -u $username git clone --depth 1 "$1" "$dir"
#
# 				# Since we compile as root, git could complain about dubious permissions, if using submodules for instance
# 				git config --global --add safe.directory "$dir"
#
# 				pushd "$dir"
# 		fi
#
# 		make
# 		make install
#
# 		popd
# }


# "Installing the Python package \`$1\` ($n of $total). $1 $2"
# installPip() {
# 		[ -x "$(command -v "pip")" ] || installPkg python-pip >/dev/null 2>&1
# 		yes | pip install "$1"
# }
#
# installNodePkg() {
# 	[ -x "$(command -v "npm")" ] || installPkg npm >/dev/null 2>&1
# 	sudo npm install -g "$1"
# }


installationLoop() {

#		aurinstalled=$(pacman -Qqm)

    pacPackages=()
    aurPackages=()

		# Read CSV line by line and install with specified method
		while IFS=, read -r tag program comment; do
        program=$(echo "$program" | tr -d '"')
				case "$tag" in
          "PAC") pacPackages+=($program)  ;;
          "AUR") aurPackages+=($program) ;;
#						"GIT") installGitMake "$program"  ;;
#						"PIP") installPip "$program"  ;;
#						"NPM") installNodePkg "$program" ;;
#						*) installPkg "$program"  ;;
				esac
		done < <(echo "$apps") ;
#		done < /tmp/progs.csv ;

    installPkg "${pacPackages[@]}"
    installPkgAur "${aurPackages[@]}"
}

newPerms() { # Set special sudoers settings for install (or after).
		sed -i "/#FROM_INSTALL_SCRIPT/d" /etc/sudoers
		echo "$* #FROM_INSTALL_SCRIPT" >> /etc/sudoers
}


# Install most basic tools for this script to work
pacman --noconfirm --needed -S curl ca-certificates base-devel git ntp zsh

# Initialize directory for source code from git repos
mkdir -p "$repodir"
chown -R $username:wheel "$(dirname "$repodir")"

# "Synchronizing system time to ensure successful and secure installation of software..."
pgrep ntpd || ntpd -q
systemctl enable --now ntpd.service

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newPerms "%wheel ALL=(ALL) NOPASSWD: ALL"

# Make pacman colorful and adds eye candy on the progress bar because why not.
#grep -q "^Color" /etc/pacman.conf || sed -i "s/^#Color$/Color/" /etc/pacman.conf
#grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
# sed -i "s/^#ParallelDownloads = 8$/ParallelDownloads = 5/" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

# Install the AUR helper tool
installAurhelper

# Install all the software from the CSV list file
installationLoop

# "Finally, installing libxft-bgra to enable color emoji in suckless software without crashes."

# TBD: Not sure if still needed from AUR, better from main?
# sudo -u $username yay --noconfirm --needed -S libxft-bgra-git


# dotfiles, using chezmoi manager
#chezmoi init --apply $dotfilesrepo



# Make zsh the default shell for the user.
chsh -s /bin/zsh $username
sudo -u $username mkdir -p "/home/$username/.cache/zsh/"


# libvirt config
sudo usermod -a -G libvirt dassi
sudo systemctl enable --now libvirtd.service 
sudo systemctl enable --now virtlogd.service

# Some stuff after all software is installed
# Give nginx access to the path to all dev web_root, which are beneath the home dir
setfacl -m g:http:x /home/dassi
sudo usermod -a -G http dassi

# start some services
sudo usermod -a -G seat dassi
sudo systemctl enable --now seatd.service

sudo systemctl restart input-remapper
sudo systemctl enable input-remapper

# (legacy) cron job service, but we need it still
sudo systemctl enable --now cronie

# Enable TRIM-ing SSD devices periodically
sudo systemctl enable --now fstrim.timer

# Start SSH daemon
sudo systemctl enable --now sshd.service


# start CUPS print service
sudo systemctl enable --now cups.service

# start avahi network discovery service
sudo systemctl enable --now avahi-daemon.service

# Removable media service automounter
sudo systemctl enable --now udisks2.service

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
newPerms "%wheel ALL=(ALL) ALL #FROM_INSTALL_SCRIPT
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/paru,/usr/bin/pacman -Syyuw --noconfirm"

echo "Now install your chezmoi files with: chezmoi init --apply <gitrepo>"

echo "complete. maybe reboot?"
