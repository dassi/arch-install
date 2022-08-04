#!/bin/sh

# ====================================================
# Linux provisioning script.
# Run as root.
# Inspired and taken from LARBS (Luke Smith).
# Made to be rerun.
# Keep me up to date.
#
# TBD: Automatically save a list of installed packages, instead of csv list in here.
#

set -e

dotfilesrepo="https://github.com/dassi/dotfiles.git"
username="dassi"

# Directory, where the git repositories for compiling will be stored
repodir="/home/$username/.local/src"

#TAG,NAME IN REPO (or git url),PURPOSE (should be a verb phrase to sound right while installing)
apps=$(cat <<EOF
PAC,xorg-server,"is the graphical server."
PAC,xorg-xwininfo,"allows querying information about windows."
PAC,xorg-xinit,"starts the graphical server."
PAC,ttf-linux-libertine,"provides the sans and serif fonts"
AUR,lf-git,"is an extensive terminal file manager that everyone likes."
PAC,bc,"is used for a dropdown calculator."
PAC,xcompmgr,"is for transparency and removing screen-tearing."
PAC,xorg-xprop,"is a tool for detecting window properties."
PAC,arandr,"allows the user to customize monitor arrangements."
PAC,dosfstools,"allows your computer to access dos-like filesystems."
PAC,libnotify,"allows desktop notifications."
PAC,dunst,"is a suckless notification system."
PAC,exfat-utils,"allows management of FAT drives."
PAC,sxiv,"is a minimalist image viewer."
PAC,xwallpaper,"sets the wallpaper."
PAC,ffmpeg,"can record and splice video and audio on the command line."
PAC,gnome-keyring,"serves as the system keyring."

AUR,gtk-theme-arc-gruvbox-git,"gives the dark GTK theme used in LARBS."

PAC,neovim,"a tidier vim with some useful features"
PAC,mpv,"is the patrician's choice video player."
PAC,man-db,"lets you read man pages of programs."

PAC,noto-fonts-emoji,"is an emoji font."

PAC,pipewire,"is the audio system."
PAC,pipewire-pulse,"gives pipewire compatibility with PulseAudio programs."
PAC,pulsemixer,"is an audio controller."
PAC,pamixer,"is a command-line audio interface."
PAC,maim,"can take quick screenshots at your request."
PAC,unclutter,"hides an inactive mouse."
PAC,unrar,"extracts rar's."
PAC,unzip,"unzips zips."
PAC,lynx,"is a terminal browser."
PAC,xcape,"gives the special escape/super mappings of LARBS."
PAC,xclip,"allows for copying and pasting from the command line."
PAC,xdotool,"provides window action utilities on the command line."
PAC,xorg-xdpyinfo,"aids with resolution determination and screen recording."
PAC,zathura,"is a pdf viewer with vim-like bindings."
PAC,zathura-pdf-mupdf,"allows mupdf pdf compatibility in zathura."
PAC,poppler,"manipulates .pdfs and gives .pdf previews and other .pdf functions."
PAC,mediainfo,"shows audio and video information."
PAC,atool,"manages and gives information about archives."
PAC,fzf,"is a fuzzy finder tool."

PAC,highlight,"can highlight code output."

PAC,xorg-xbacklight,"enables changing screen brightness levels."
AUR,zsh-fast-syntax-highlighting,"provides syntax highlighting in the shell."
AUR,htop,"is a graphical and colorful system monitor."
GIT,https://git.suckless.org/dmenu,"runs commands and provides a UI for selection."
GIT,https://git.suckless.org/st,"is my custom build of suckless's terminal emulator."
GIT,https://github.com/dassi/dwm.git,"is the window manager. TODO use the dassi branch"
PAC,slock,"allows you to lock your computer, and quickly unlock with your password."
PAC,firefox,"Firefox web browser"
PAC,thunderbird,"Email client GUI"
PAC,socat,"is a utility which establishes two byte streams and transfers data between them."
PAC,moreutils,"is a collection of useful unix tools."
PAC,rsync,"rsync"
PAC,nginx,"webserver for local development"
PAC,chezmoi,"dotfiles manager"
EOF
)

#ERROR A,htop-vim-git,"is a graphical and colorful system monitor."
# TBD some statusbar GIT,https://git.suckless.org/dwmblocks,"serves as the modular status bar."
#AUR,mutt-wizard-git,"is a light-weight terminal-based email system."
#AUR,task-spooler,"queues commands or files for download."

installPkg(){
		pacman --noconfirm --needed -S "$1"
}

# Installing from AUR
installPkgAur() {
		echo "$aurinstalled" | grep -q "^$1$" && return
		sudo -u $username yay -S --noconfirm --needed "$1"
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


installGitMake() {
		progname="$(basename "$1" .git)"
		dir="$repodir/$progname"
		if [ -d "$dir" ]; then
				pushd "$dir"
				#sudo -u $username git pull --force origin master;
				sudo -u $username git pull --force origin;
		else
				sudo -u $username git clone --depth 1 "$1" "$dir"

				# Since we compile as root, git could complain about dubious permissions, if using submodules for instance
				git config --global --add safe.directory "$dir"

				pushd "$dir"
		fi

		make
		make install

		popd
}


# "Installing the Python package \`$1\` ($n of $total). $1 $2"
installPip() {
		[ -x "$(command -v "pip")" ] || installPkg python-pip >/dev/null 2>&1
		yes | pip install "$1"
}



installationLoop() {

		# Remove commented lines
#		sed '/^#/d' ./arch_progs.csv > /tmp/progs.csv
		
		aurinstalled=$(pacman -Qqm)

		# Read CSV line by line and install with specified method
		while IFS=, read -r tag program comment; do
				n=$((n+1))
				case "$tag" in
						"PAC") installPkg "$program"  ;;
						"AUR") installPkgAur "$program" ;;
						"GIT") installGitMake "$program"  ;;
						"PIP") installPip "$program"  ;;
						*) installPkg "$program"  ;;
				esac
		done < <(echo "$apps") ;
#		done < /tmp/progs.csv ;
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

# # "Refreshing Arch Keyring..."
# pacman --noconfirm --needed -S artix-keyring artix-archlinux-support
# for repo in extra community multilib; do
# 		grep -q "^\[$repo\]" /etc/pacman.conf ||
# 				echo "[$repo]
# Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf
# done
# pacman -Sy > /dev/null 2>&1
# pacman-key --populate archlinux

# "Synchronizing system time to ensure successful and secure installation of software..."
ntpdate 0.europe.pool.ntp.org

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newPerms "%wheel ALL=(ALL) NOPASSWD: ALL"

# Make pacman colorful and adds eye candy on the progress bar because why not.
grep -q "^Color" /etc/pacman.conf || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
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

# TBD Falls Probleme: Zur Zeit git Problmeme mit https bei gitlab.freedekstop für dependency libxft
# pushd /tmp
# sudo -u $username yay --noconfirm --needed -G libxft-bgra-git
# pushd libxft-bgra-git
# sed -i "s/https:\/\/gitlab.freedesktop.org\/xorg\/lib\/libxft.git/git:\/\/cgit.freedesktop.org\/xorg\/lib\/libXft.git/" PKGBUILD
# sed -i "s/_dir=libxft/_dir=libXft/" PKGBUILD
# makepkg
# popd
# popd



# Install the dotfiles in the user's home directory
# dir=$(mktemp -d)
# chown $username:wheel "$dir" /home/$username
# sudo -u $username git clone --recursive -b master --depth 1 --recurse-submodules "$dotfilesrepo" "$dir"
# sudo -u $username cp -rfT "$dir" /home/$username

# Delete unused files from dotfiles repo

# # make git ignore deleted LICENSE & README.md files
# pushd /home/$username
# rm -f "README.md" "LICENSE" "FUNDING.yml"
# git update-index --assume-unchanged "/home/$username/README.md" "/home/$username/LICENSE" "/home/$username/FUNDING.yml"
# popd

# dotfiles, using chezmoi manager
#chezmoi init --apply $dotfilesrepo



# Make zsh the default shell for the user.
chsh -s /bin/zsh $username
sudo -u $username mkdir -p "/home/$username/.cache/zsh/"

# Tap to click
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && echo 'Section "InputClass"
	Identifier "libinput touchpad catchall"
	MatchIsTouchpad "on"
	MatchDevicePath "/dev/input/event*"
	Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' > /etc/X11/xorg.conf.d/40-libinput.conf

# # Start/restart PulseAudio.
# killall pulseaudio; sudo -u $username pulseaudio --start

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
newPerms "%wheel ALL=(ALL) ALL #FROM_INSTALL_SCRIPT
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/paru,/usr/bin/pacman -Syyuw --noconfirm"


echo "complete. maybe reboot?"

