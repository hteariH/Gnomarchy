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

# The plymouth hook is in /etc/mkinitcpio.conf.d/gnomarchy.conf, written by
# default/boot/deploy.sh. Editing HOOKS here used to insert it after `udev`,
# which a systemd HOOKS line never contains, so it never happened.

gnomarchy_step "Boot splash prepared"
