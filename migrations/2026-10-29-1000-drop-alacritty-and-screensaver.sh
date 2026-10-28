#!/bin/bash
# Alacritty and the retro screensaver are gone.
#
# GNOME Terminal has been the terminal since 2026-09-10; Alacritty stayed as a
# themed second terminal and as the screensaver's window, and nothing else
# used either. This removes the package, the theme engine's colors.toml and
# the screensaver's Super+Escape binding (slot custom5 on the default layout).
#
# Idempotent: each step checks before it acts. ~/.config/alacritty/alacritty.toml
# is left alone - it may hold the user's own settings.
set -eEo pipefail

if pacman -Q alacritty >/dev/null 2>&1; then
  # -Rs, not -Rns: keep any config pacman tracks as a .pacsave.
  if sudo pacman -Rs --noconfirm alacritty; then
    echo "  Removed the alacritty package."
  else
    echo "  Could not remove alacritty (something may depend on it); leaving it installed."
  fi
fi

# Written by the theme engine before it stopped theming Alacritty.
rm -f "$HOME/.config/alacritty/colors.toml"

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && ! -S "/run/user/$(id -u)/bus" ]]; then
  # As the other dconf migrations do: outside a session there is no dconf to
  # edit. The leftover binding only points at a command that no longer exists.
  echo "No session bus; the Super+Escape binding is left in place (it now does nothing)."
  exit 0
fi
command -v gsettings >/dev/null 2>&1 || exit 0

MEDIA_KEYS="org.gnome.settings-daemon.plugins.media-keys"
SLOT_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
SLOT_SCHEMA="$MEDIA_KEYS.custom-keybinding:$SLOT_PATH"

command="$(gsettings get "$SLOT_SCHEMA" command)"
# Only the slot that still runs the screensaver: the Omarchy layout uses
# custom5 for its system menu, and a user may have repurposed it.
if [[ "$command" == "'gnomarchy screensaver'" ]]; then
  current="$(gsettings get "$MEDIA_KEYS" custom-keybindings)"
  current="${current//, \'$SLOT_PATH\'/}"
  current="${current//\'$SLOT_PATH\', /}"
  current="${current//\'$SLOT_PATH\'/}"
  [[ "$current" == "[]" ]] && current="@as []"
  gsettings set "$MEDIA_KEYS" custom-keybindings "$current"
  gsettings reset "$SLOT_SCHEMA" name
  gsettings reset "$SLOT_SCHEMA" command
  gsettings reset "$SLOT_SCHEMA" binding
  echo "  Super+Escape no longer starts the screensaver."
fi
