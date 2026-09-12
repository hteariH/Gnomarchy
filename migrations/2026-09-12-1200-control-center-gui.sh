#!/bin/bash

# The menu, the keybindings browser and the manual are now one GTK
# application. Adding gjs/gtk4/libadwaita to gnomarchy-base.packages reaches
# new installs only, so an existing machine needs them installed here.
#
# Keybindings are deliberately untouched: the three commands that open the GUI
# keep the names they always had, so whatever they were bound to still works.
#
# Idempotent: --needed installs nothing that is already present, and cp -f
# rewrites a file that may already be identical. Needs no session bus, unlike
# most migrations here.
set -eEo pipefail

GNOMARCHY_PATH="${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}"

echo "Installing the control center's runtime..."
sudo pacman -S --needed --noconfirm gjs gtk4 libadwaita

DESKTOP_SOURCE="$GNOMARCHY_PATH/default/applications/org.gnomarchy.ControlCenter.desktop"
APPLICATIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

if [[ -f "$DESKTOP_SOURCE" ]]; then
  mkdir -p "$APPLICATIONS_DIR"
  cp -f "$DESKTOP_SOURCE" "$APPLICATIONS_DIR/"
  echo "  Published the control center desktop entry."
else
  echo "  No desktop entry found at $DESKTOP_SOURCE; run 'gnomarchy update' first." >&2
fi

echo "The control center is installed. Super+Alt+Space, Super+K and Super+Shift+K now open it."
