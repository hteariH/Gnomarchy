#!/bin/bash
# Super+1..6 did two things at once.
#
# install/desktop/set-gnome-hotkeys.sh binds switch-to-workspace-1..6 to
# Super+1..6, and `gnomarchy keymap omarchy` takes all ten digits. GNOME Shell
# ships switch-to-application-1..9 on those same Super+N by default, in
# org.gnome.shell.keybindings. So every one of those keys had two handlers and
# did whichever the shell registered last -- switch workspace, or focus the Nth
# favourite in the dock.
#
# Turning off Dash to Dock's hot-keys, which the installer already does, is a
# different setting and never touched the Shell's own.
#
# What to unbind depends on the keymap profile, so rather than hardcode a
# range this reads what the workspace keys are actually bound to and mirrors
# it: a digit claimed by a workspace loses its app shortcut, a digit that is
# not claimed gets GNOME's default back.
#
# Idempotent by construction: it computes the desired state from dconf every
# time and writes that, so running it twice changes nothing the second time.
set -eEo pipefail

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && ! -S "/run/user/$(id -u)/bus" ]]; then
  echo "No session bus; skipping (this migration needs a desktop session)."
  exit 0
fi

command -v gsettings >/dev/null 2>&1 || exit 0

WM="org.gnome.desktop.wm.keybindings"
SHELL_KEYS="org.gnome.shell.keybindings"

gsettings list-schemas 2>/dev/null | grep -qx "$SHELL_KEYS" || {
  echo "  $SHELL_KEYS is not installed; nothing to do."
  exit 0
}

# Which digits do the workspace shortcuts currently claim?
claimed=""
for i in $(seq 1 10); do
  value="$(gsettings get "$WM" "switch-to-workspace-$i" 2>/dev/null || echo '')"
  # "['<Super>3']" -> 3. Only bare Super+digit matters; anything else is not
  # competing with switch-to-application.
  while read -r digit; do
    [[ -n "$digit" ]] && claimed+=" $digit"
  done < <(grep -oE "<Super>[0-9]" <<<"$value" | grep -oE '[0-9]$')
done

unbound=0
restored=0
for n in $(seq 1 9); do
  current="$(gsettings get "$SHELL_KEYS" "switch-to-application-$n" 2>/dev/null || echo '')"

  if [[ " $claimed " == *" $n "* ]]; then
    # A workspace owns Super+N. The app shortcut has to go.
    if [[ "$current" != "@as []" && "$current" != "[]" ]]; then
      gsettings set "$SHELL_KEYS" "switch-to-application-$n" "@as []"
      echo "  Super+$n switches to workspace; unbound switch-to-application-$n"
      unbound=$((unbound + 1))
    fi
  else
    # No workspace on Super+N, so GNOME's default belongs there again.
    if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
      gsettings reset "$SHELL_KEYS" "switch-to-application-$n"
      echo "  Super+$n is free; restored switch-to-application-$n"
      restored=$((restored + 1))
    fi
  fi
done

if ((unbound == 0 && restored == 0)); then
  echo "  Workspace and application shortcuts already agree; nothing to change."
else
  echo "  Resolved $unbound double-bound and $restored unclaimed Super+digit key(s)."
fi
