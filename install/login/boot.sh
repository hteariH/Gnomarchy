#!/bin/bash

gnomarchy_header "Configuring the Limine Boot Menu"

# The ISO installer already deployed the boot tooling before installing the
# bootloader; this run finds it in place and only regenerates the menu with
# the theme set in the config stage.
if [[ -f /etc/gnomarchy/boot.conf ]]; then
  sudo bash "$GNOMARCHY_PATH/default/boot/deploy.sh"
  sudo /usr/local/lib/gnomarchy/boot/gnomarchy-boot update
  gnomarchy_step "Limine menu generated"
else
  gnomarchy_warn "Not installed from the Gnomarchy ISO; the bootloader is left as it is."
fi
