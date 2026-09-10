#!/bin/bash

# Desktop configuration writes to dconf, which needs a live D-Bus session bus.
# Inside arch-chroot there is none, so every gsettings write would be silently
# discarded -- and custom keybindings, which cannot be expressed as gschema
# overrides, would be lost entirely. Defer the whole stage to first login.
gnomarchy_can_write_dconf() {
  [[ -z "$GNOMARCHY_CHROOT_INSTALL" ]] || return 1
  [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" || -S "/run/user/$(id -u)/bus" ]] || return 1
  command -v gsettings >/dev/null 2>&1 || return 1
  return 0
}

# Extensions and their schemas are installed system-wide, so this part works
# without a session bus and must happen during installation.
source "$GNOMARCHY_INSTALL/desktop/install-extension-files.sh"

if gnomarchy_can_write_dconf; then
  source "$GNOMARCHY_INSTALL/desktop/set-gnome-settings.sh"
  source "$GNOMARCHY_INSTALL/desktop/set-gnome-extensions.sh"
  source "$GNOMARCHY_INSTALL/desktop/set-gnome-terminal.sh"
  source "$GNOMARCHY_INSTALL/desktop/set-gnome-favorites.sh"
  source "$GNOMARCHY_INSTALL/desktop/set-gnome-hotkeys.sh"
else
  gnomarchy_header "Deferring Desktop Configuration to First Login"
  gnomarchy_substep "No D-Bus session bus available in this context."
  gnomarchy_substep "Keyboard shortcuts and dconf settings will be applied at first login."

  mkdir -p "$HOME/.config/autostart"
  cat > "$HOME/.config/autostart/gnomarchy-first-run.desktop" <<'AUTOSTART'
[Desktop Entry]
Type=Application
Name=Gnomarchy First Run Setup
Comment=Applies Gnomarchy desktop settings and keyboard shortcuts
Exec=/usr/local/bin/gnomarchy first-run
Icon=preferences-desktop
Terminal=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Applications
NoDisplay=true
AUTOSTART

  gnomarchy_step "First-login setup scheduled"
fi

source "$GNOMARCHY_INSTALL/desktop/set-nautilus-actions.sh"
