#!/bin/bash

set -e

export GNOMARCHY_ONLINE_INSTALL=true

ansi_art='
   ▄████████ █▄       ▄█     ▄████████  ▄▄▄▄███▄▄▄▄      ▄████████     ███        ▄██   ▄      
  ███    ███ ███     ███    ███    ███▄██▀▀▀███▀▀▀██▄   ███    ███ ▀█████████▄   ███   ██▄    
  ███    █▀  ███     ███    ███    ██████   ███   ███   ███    ███    ▀███▀▀██   ███▄▄▄███    
 ▄███        ███     ███    ███    ██████   ███   ███   ███    ███     ███   ▀   ▀▀▀▀▀▀███    
▀▀███ ████▄  ███     ███  ▀██████████████   ███   ███ ▀███████████     ███       ▄██   ███    
  ███    ███ ███     ███    ███    ██████   ███   ███   ███    ███     ███       ███   ███    
  ███    ███ ███ ▄█▄ ███    ███    ██████   ███   ███   ███    ███     ███       ███   ███    
  ████████▀   ▀███▀███▀     ███    █▀  ▀█   ███   █▀    ███    █▀     ▄████▀      ▀█████▀     
                                  GNOME Meets Arch Linux
'

clear
echo -e "\e[36m$ansi_art\e[0m\n"

# Use custom branch/repo if instructed
GNOMARCHY_REF="${GNOMARCHY_REF:-main}"
GNOMARCHY_REPO="${GNOMARCHY_REPO:-hteariH/Gnomarchy}"

echo -e "Installing base prerequisites..."
sudo pacman -Syu --noconfirm --needed git curl base-devel

echo -e "\nCloning Gnomarchy from: https://github.com/${GNOMARCHY_REPO}.git"
echo -e "\e[32mUsing branch: $GNOMARCHY_REF\e[0m"
rm -rf ~/.local/share/gnomarchy/
git clone --branch "$GNOMARCHY_REF" "https://github.com/${GNOMARCHY_REPO}.git" ~/.local/share/gnomarchy >/dev/null

echo -e "\nStarting Gnomarchy installation..."
source ~/.local/share/gnomarchy/install.sh
