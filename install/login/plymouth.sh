#!/bin/bash

gnomarchy_header "Configuring Plymouth Boot Splash"

# Install Gnomarchy Plymouth theme if present in default/plymouth
if [ -d "$GNOMARCHY_PATH/default/plymouth" ]; then
  sudo mkdir -p /usr/share/plymouth/themes/gnomarchy
  sudo cp -r "$GNOMARCHY_PATH/default/plymouth/"* /usr/share/plymouth/themes/gnomarchy/ 2>/dev/null || true
  
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    sudo plymouth-set-default-theme gnomarchy 2>/dev/null || sudo plymouth-set-default-theme bgrt 2>/dev/null || true
  fi
fi

# Ensure mkinitcpio has plymouth hook if installed
if [ -f /etc/mkinitcpio.conf ]; then
  if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
    sudo sed -i 's/HOOKS=(\(.*\)udev\(.*\)filesystems\(.*\))/HOOKS=(\1udev plymouth\2filesystems\3)/' /etc/mkinitcpio.conf 2>/dev/null || true
  fi
fi

gnomarchy_step "Boot splash prepared"
