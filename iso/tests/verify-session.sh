#!/bin/bash

# In-guest session verification.
#
# Runs inside the installed system's first graphical session, after the
# gnomarchy-first-run autostart entry has done its work. These are the checks
# that cannot be made offline: dconf only holds them once a session with a
# D-Bus bus has actually applied them.
#
# Writes results to /var/tmp/gnomarchy-session-verify.txt and powers off, so
# CI reads the outcome from the disk image rather than the serial console.
# Progress also goes to the journal. A report written only to a file tells us
# nothing when the script hangs before finishing, which is exactly what
# happened: the run timed out with no output at all.
trace() { logger -t gnomarchy-verify -- "$*" 2>/dev/null || true; }

trace "verify-session started as $(whoami), session=${XDG_SESSION_TYPE:-unknown}"

exec >"/var/tmp/gnomarchy-session-verify.txt" 2>&1

pass=0
fail=0
ok() {
  echo "PASS  $1"
  trace "PASS $1"
  pass=$((pass + 1))
}
no() {
  echo "FAIL  $1${2:+ -- $2}"
  trace "FAIL $1 ${2:-}"
  fail=$((fail + 1))
}

# first-run is an autostart entry; give it time to finish before sampling
# dconf, but do not wait forever - report what we see instead of hanging.
trace "waiting for first-run to finish"
for i in $(seq 1 24); do
  [[ -f "$HOME/.local/state/gnomarchy/first-run.done" ]] && break
  sleep 5
done
trace "first-run stamp present: $([[ -f "$HOME/.local/state/gnomarchy/first-run.done" ]] && echo yes || echo no)"

echo "=== Session verification ==="
echo "session type: ${XDG_SESSION_TYPE:-unknown}"
echo

if [[ -f "$HOME/.local/state/gnomarchy/first-run.done" ]]; then
  ok "gnomarchy-first-run completed"
else
  no "gnomarchy-first-run never completed" "autostart entry did not run"
fi

# --- Regression: no keyboard shortcut worked at all ------------------------
BINDINGS="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
custom_list="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null)"
if [[ "$custom_list" == *custom0* ]]; then
  ok "custom keybinding slots registered"
else
  no "no custom keybinding slots" "got: $custom_list"
fi

check_binding() {
  local slot="$1" expect_key="$2" label="$3"
  local schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDINGS/$slot/"
  local binding
  binding="$(gsettings get "$schema" binding 2>/dev/null | tr -d "'")"
  if [[ "$binding" == "$expect_key" ]]; then
    ok "$label bound to $expect_key"
  else
    no "$label not bound" "expected $expect_key, got '${binding:-nothing}'"
  fi
}

check_binding custom0 "<Super>Return" "terminal"
check_binding custom4 "<Super>d" "Voxtype dictation"
check_binding custom6 "<Super><Alt>space" "command center"

# Window shortcuts come from the gschema override, so they must hold too.
close_key="$(gsettings get org.gnome.desktop.wm.keybindings close 2>/dev/null)"
[[ "$close_key" == *"<Super>w"* ]] &&
  ok "Super+W closes windows" ||
  no "Super+W not bound" "got: $close_key"

ws1="$(gsettings get org.gnome.desktop.wm.keybindings switch-to-workspace-1 2>/dev/null)"
[[ "$ws1" == *"<Super>1"* ]] &&
  ok "Super+1 switches workspace" ||
  no "Super+1 not bound" "got: $ws1"

# --- Regression: dock stayed at the default bottom position ---------------
dock_pos="$(gsettings get org.gnome.shell.extensions.dash-to-dock dock-position 2>/dev/null | tr -d "'")"
[[ "$dock_pos" == "LEFT" ]] &&
  ok "dock is on the left" ||
  no "dock is not on the left" "got '${dock_pos:-unset}'"

# --- Regression: two identical Brave icons in the dash --------------------
favs="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null)"
brave_count="$(grep -o 'brave' <<<"$favs" | wc -l)"
((brave_count == 1)) &&
  ok "exactly one Brave entry in the dock" ||
  no "$brave_count Brave entries in the dock" "$favs"

# --- Regression: wallpaper fell back to the bundled SVG placeholder -------
wallpaper="$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'")"
if [[ "$wallpaper" == *.svg ]]; then
  no "wallpaper is the bundled SVG placeholder" "$wallpaper"
else
  ok "wallpaper is a real image ($(basename "$wallpaper"))"
fi
[[ -f "${wallpaper#file://}" ]] &&
  ok "wallpaper file exists on disk" ||
  no "wallpaper path does not exist" "$wallpaper"

# --- Terminal palette is actually applied ---------------------------------
term_uuid="$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")"
term_profile="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$term_uuid/"
palette="$(gsettings get "$term_profile" palette 2>/dev/null)"
colors="$(grep -o '#' <<<"$palette" | wc -l)"
((colors == 16)) &&
  ok "GNOME Terminal has a full 16-colour palette" ||
  no "terminal palette not applied" "$colors colours"

# --- Regression: an icon theme installed but never applied -----------------
# papirus-icon-theme was in the package list from the start and nothing ever
# set it, so every install ran on Adwaita and the package was dead weight.
icons="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"
if [[ "$icons" == Papirus* ]]; then
  ok "icon theme is applied ($icons)"
else
  no "icon theme is not a Papirus variant" "got: ${icons:-unset}"
fi

# Not a check, a question this test is the right place to answer: which icon
# the editor entry actually asks for, and whether anything provides it. The
# icon looked wrong in a screenshot and the cause was guessed at rather than
# established.
for entry in /usr/share/applications/code-oss.desktop   /usr/share/applications/visual-studio-code.desktop   /usr/share/applications/code.desktop; do
  [[ -f "$entry" ]] || continue
  icon_name="$(sed -n 's/^Icon=//p' "$entry" | head -1)"
  echo "INFO  $(basename "$entry") asks for Icon=$icon_name"
  found="$(find /usr/share/icons /usr/share/pixmaps -name "$icon_name.*" 2>/dev/null | head -3)"
  echo "INFO  provided by: ${found:-nothing}"
done

echo
echo "=== $pass passed, $fail failed ==="
echo "RESULT: $([[ $fail -eq 0 ]] && echo SUCCESS || echo FAILURE)"

sync
trace "verification finished: $pass passed, $fail failed"

# Powering off ends the CI run. Go through sudo, which has an explicit
# NOPASSWD rule: a bare systemctl poweroff depends on polkit granting it, and
# if that is refused the script hangs and the whole job times out.
sudo -n systemctl poweroff 2>/dev/null ||
  systemctl poweroff 2>/dev/null ||
  sudo -n reboot 2>/dev/null ||
  trace "could not power off"
