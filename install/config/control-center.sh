#!/bin/bash

gnomarchy_header "Installing the Gnomarchy Control Center"

# Nothing is built: the app is GJS source that arrives with the repository and
# updates with `git pull`, like everything else here. All this stage does is
# publish the desktop entry so the app is reachable from the Overview as well
# as from Super+Alt+Space.
#
# No dconf is written, so this works inside arch-chroot: the three commands
# that launch it are already bound by install/desktop/set-gnome-hotkeys.sh.
APPLICATIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP_SOURCE="$GNOMARCHY_PATH/default/applications/org.gnomarchy.ControlCenter.desktop"

if [[ ! -f "$DESKTOP_SOURCE" ]]; then
  gnomarchy_warn "No desktop entry at $DESKTOP_SOURCE; skipping."
  return 0 2>/dev/null || exit 0
fi

mkdir -p "$APPLICATIONS_DIR"
cp -f "$DESKTOP_SOURCE" "$APPLICATIONS_DIR/"

gnomarchy_step "Control center published to $APPLICATIONS_DIR"
