#!/bin/bash
# GNOME input sources from the layout picked in the installer. This writes
# dconf, so it runs from gnomarchy-first-run, never inside the chroot.

KEYBOARD_CONF=/etc/gnomarchy/keyboard.conf
if [[ -f "$KEYBOARD_CONF" ]]; then
  xkb_layout="$(sed -n 's/^XKB_LAYOUT=//p' "$KEYBOARD_CONF")"
  xkb_variant="$(sed -n 's/^XKB_VARIANT=//p' "$KEYBOARD_CONF")"
  latin="$(sed -n 's/^LATIN=//p' "$KEYBOARD_CONF")"
  source_id="${xkb_layout:-us}${xkb_variant:++$xkb_variant}"
  # A non-Latin layout keeps US first: shortcuts and Latin input stay usable.
  if [[ "$latin" == no ]]; then
    sources="[('xkb', 'us'), ('xkb', '$source_id')]"
  else
    sources="[('xkb', '$source_id')]"
  fi
  gsettings set org.gnome.desktop.input-sources sources "$sources"
  gnomarchy_step "Keyboard layout: $source_id"
fi
