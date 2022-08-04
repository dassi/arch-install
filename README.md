# Arch Linux installation

My personal arch install helper scripts. Starting point for a fresh arch install.
Serves as a low tech provisioning, since I did not want to rely on libraries like ansible or
similar, since this would be overkill and not future proof.

Initially taken (thanks!) and simplified from Luke Smith: https://larbs.xyz/ (https://github.com/lukesmithxyz/larbs)

## Usage

- Boot from an arch ISO
- Follow the steps in the pseudo shell script: curl -LO https://github.com/dassi/arch-install/raw/main/01_arch_install_linux.sh
- After booting into the basic arch linux, get and run the other script: curl -LO https://github.com/dassi/arch-install/raw/main/02_arch_install_desktop.sh

## Scope

- Installs dwm window manager, from my personal repo, with my own key bindings
- Installs lots of arch packages, suited for my development environment
- Configures for a swiss german keyboard

## Create an ISO

TBD
