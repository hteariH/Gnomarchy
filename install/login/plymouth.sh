#!/bin/bash

gnomarchy_header "Configuring Plymouth Boot Splash"

# Install Gnomarchy Plymouth theme if present in default/plymouth
if [ -d "$GNOMARCHY_PATH/default/plymouth" ]; then
  sudo mkdir -p /usr/share/plymouth/themes/gnomarchy
  sudo cp -r "$GNOMARCHY_PATH/default/plymouth/"* /usr/share/plymouth/themes/gnomarchy/ 2>/dev/null || true
  
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    # -R rebuilds the initramfs, which is where the theme is read from at boot;
    # mkinitcpio's post hook then regenerates the Limine menu's hashes.
    if sudo plymouth-set-default-theme -R gnomarchy; then
      gnomarchy_substep "Plymouth theme: gnomarchy"
    elif sudo plymouth-set-default-theme -R bgrt; then
      gnomarchy_warn "The gnomarchy Plymouth theme did not apply; using bgrt"
    else
      gnomarchy_warn "Could not set a Plymouth theme; the boot splash keeps its default"
    fi
  fi
fi

# The plymouth hook is in /etc/mkinitcpio.conf.d/gnomarchy.conf, written by
# default/boot/deploy.sh. Editing HOOKS here used to insert it after `udev`,
# which a systemd HOOKS line never contains, so it never happened.

gnomarchy_step "Boot splash prepared"
