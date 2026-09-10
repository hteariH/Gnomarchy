#!/bin/bash

gnomarchy_header "Configuring Pacman Package Manager"

# Enable parallel downloads and ILoveCandy if not already configured
sudo sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
  sudo sed -i '/ParallelDownloads = 5/a ILoveCandy' /etc/pacman.conf
fi

# Enable multilib repository if commented out
if grep -q "^#\[multilib\]" /etc/pacman.conf; then
  sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
fi

# Refresh package databases
sudo pacman -Sy --noconfirm
gnomarchy_step "Pacman optimized and databases synchronized"
