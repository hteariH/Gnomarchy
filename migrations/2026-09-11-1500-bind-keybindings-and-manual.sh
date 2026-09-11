#!/bin/bash
# Super+K and Super+Shift+K were never bound on the default layout.
#
# gnomarchy-keymap's "gnome" branch registers custom0..custom8, and
# `gnomarchy keymap status` tells the user that Super+K opens the searchable
# keybindings and Super+Shift+K opens the manual. But the layout that actually
# runs at first login comes from install/desktop/set-gnome-hotkeys.sh, which
# stopped at custom6. So both commands existed, were on PATH, were documented
# in the product itself -- and had no key.
#
# Idempotent: re-registering a slot that is already listed and re-setting a
# binding it already has changes nothing.
set -eEo pipefail

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && ! -S "/run/user/$(id -u)/bus" ]]; then
  echo "No session bus; skipping (this migration needs a desktop session)."
  exit 0
fi

command -v gsettings >/dev/null 2>&1 || exit 0

MEDIA_KEYS="org.gnome.settings-daemon.plugins.media-keys"
BINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
SLOT_SCHEMA="$MEDIA_KEYS.custom-keybinding"

# Leave any slot the user added alone: only append the two that are missing.
current="$(gsettings get "$MEDIA_KEYS" custom-keybindings 2>/dev/null || echo "@as []")"

bind_slot() {
  local slot="$1" name="$2" command="$3" binding="$4"
  local path="$BINDING_PATH/$slot/"

  # Refuse to overwrite a slot the user has repurposed for something else.
  local existing
  existing="$(gsettings get "$SLOT_SCHEMA:$path" command 2>/dev/null || echo "''")"
  existing="${existing//\'/}"
  if [[ -n "$existing" && "$existing" != "$command" ]]; then
    echo "  $slot already runs '$existing'; leaving it alone."
    return 0
  fi

  gsettings set "$SLOT_SCHEMA:$path" name "$name"
  gsettings set "$SLOT_SCHEMA:$path" command "$command"
  gsettings set "$SLOT_SCHEMA:$path" binding "$binding"

  if [[ "$current" != *"$path"* ]]; then
    if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
      current="['$path']"
    else
      current="${current%]}, '$path']"
    fi
  fi
  echo "  $binding -> $command"
}

bind_slot custom7 'Keybindings' 'gnomarchy-keybindings' '<Super>k'
bind_slot custom8 'Manual' 'gnomarchy-manual' '<Super><Shift>k'

gsettings set "$MEDIA_KEYS" custom-keybindings "$current"
echo "Bound the keybindings browser and the manual."
