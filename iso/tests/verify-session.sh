#!/bin/bash

# In-guest session verification.
#
# Runs inside the installed system's first graphical session, after the
# gnomarchy-first-run autostart entry has done its work. These are the checks
# that cannot be made offline: dconf only holds them once a session with a
# D-Bus bus has actually applied them.
#
# Writes its report to ~/.local/state/gnomarchy/verify/<mode>.txt and powers
# off, so CI reads the outcome from the disk image rather than the serial
# console. /home is its own subvolume: the report survives a snapshot boot,
# whose root is a tmpfs overlay that /var/tmp used to vanish with.
# Progress also goes to the journal. A report written only to a file tells us
# nothing when the script hangs before finishing, which is exactly what
# happened: the run timed out with no output at all.
trace() { logger -t gnomarchy-verify -- "$*" 2>/dev/null || true; }

trace "verify-session started as $(whoami), session=${XDG_SESSION_TYPE:-unknown}"

MODE=session
SNAPSHOT_BOOTED=""
read -ra cmdline_words </proc/cmdline
for word in "${cmdline_words[@]}"; do
  [[ "$word" == gnomarchy.snapshot=* ]] && SNAPSHOT_BOOTED="${word#*=}"
done
[[ -n "$SNAPSHOT_BOOTED" ]] && MODE=snapshot
REPORT_DIR="$HOME/.local/state/gnomarchy/verify"
mkdir -p "$REPORT_DIR"
exec >"$REPORT_DIR/$MODE.txt" 2>&1

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

finish() {
  echo
  echo "=== $pass passed, $fail failed ==="
  echo "RESULT: $([[ $fail -eq 0 ]] && echo SUCCESS || echo FAILURE)"
  sync
  trace "verification finished ($MODE): $pass passed, $fail failed"
  # Powering off ends the CI run. Go through sudo, which has an explicit
  # NOPASSWD rule: a bare systemctl poweroff depends on polkit granting it, and
  # if that is refused the script hangs and the whole job times out.
  sudo -n systemctl poweroff 2>/dev/null ||
    systemctl poweroff 2>/dev/null ||
    sudo -n reboot 2>/dev/null ||
    trace "could not power off"
  exit 0
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

# --- Third boot: running from a snapshot ------------------------------------
if [[ "$MODE" == snapshot ]]; then
  n="$SNAPSHOT_BOOTED"
  echo "booted from snapshot $n"
  ok "a GNOME session came up from snapshot $n"
  [[ "$(findmnt -no FSTYPE /)" == overlay ]] && ok "/ is an overlay" ||
    no "/ is not an overlay" "$(findmnt -no FSTYPE,SOURCE,OPTIONS /)"
  [[ " ${cmdline_words[*]} " == *" rootflags=subvol=@snapshots/$n/snapshot "* ]] &&
    ok "the root is snapshot $n" || no "the command line does not point at snapshot $n"
  if echo probe >/var/tmp/gnomarchy-overlay-probe; then
    ok "the root accepts writes (CI checks they never reach the snapshot)"
  else
    no "the snapshot root is not writable"
  fi
  notified=0
  for _ in $(seq 1 30); do
    if journalctl --user -t gnomarchy-snapshot-notify --no-pager | grep -q "booted from snapshot $n"; then
      notified=1
      break
    fi
    sleep 1
  done
  ((notified)) && ok "the snapshot notice ran" || no "the snapshot notice never ran"
  echo "--- failed units (diagnostic only) ---"
  systemctl --failed --no-legend --no-pager
  # A transaction here put the new kernel on the persistent ESP while its
  # modules vanished with the overlay, so the guard hook must refuse it.
  if guard_out="$(/usr/local/lib/gnomarchy/boot/gnomarchy-boot guard 2>&1)"; then
    no "gnomarchy-boot guard lets a snapshot boot through"
  elif [[ "$guard_out" == *"running snapshot $n"* ]]; then
    ok "gnomarchy-boot guard refuses a snapshot boot and names it"
  else
    no "gnomarchy-boot guard refused without naming snapshot $n" "$guard_out"
  fi
  menu_before="$(b2sum /boot/limine.conf)"
  pkg="$(find /var/cache/pacman/pkg -name 'file-[0-9]*.pkg.tar.zst' | sort | tail -n1)"
  if [[ -z "$pkg" ]]; then
    no "no cached package to try a transaction with"
  elif sudo -n pacman -U --noconfirm "$pkg"; then
    no "pacman ran a transaction on a snapshot boot"
  else
    ok "pacman refuses a transaction on a snapshot boot"
  fi
  [[ "$(b2sum /boot/limine.conf)" == "$menu_before" ]] &&
    ok "the refused transaction left the menu alone" || no "the refused transaction changed limine.conf"
  if gnomarchy snapshot restore "$n" --yes; then
    ok "gnomarchy snapshot restore $n succeeded"
  else
    no "gnomarchy snapshot restore $n failed"
  fi
  grep -qx 'default_entry: Gnomarchy/linux' /boot/limine.conf &&
    ok "the menu defaults to linux again" || no "the menu does not default to linux after the restore"
  finish
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

# --- Regression: tiling enabled but not running ----------------------------
#
# Tiling Shell is the only tiling Gnomarchy ships. Enabled is not the same as
# loaded: a build that does not declare this shell's version sits in
# enabled-extensions and does nothing, which is what GNOME 51 did to the
# zips that were bundled for 50. Ask the shell, not dconf.
ts_uuid="tilingshell@ferrarodomenico.com"
ts_state="$(gnome-extensions info "$ts_uuid" 2>/dev/null | grep -i '^ *State:' | sed 's/.*: *//')"
if [[ "$ts_state" == "ACTIVE" ]]; then
  ok "Tiling Shell is running"
else
  no "Tiling Shell is not running" "shell reports state: ${ts_state:-unknown}"
fi

ts_auto="$(gsettings get org.gnome.shell.extensions.tilingshell enable-autotiling 2>/dev/null)"
if [[ "$ts_auto" == "false" ]]; then
  ok "Tiling Shell auto-placement is off"
else
  no "Tiling Shell auto-placement is not off" "enable-autotiling: ${ts_auto:-unset}"
fi

# --- Regression: two commands on one accelerator ---------------------------
#
# Gnomarchy binds Super+K to the keybindings browser and Super+Shift+K to the
# manual, and the tiling extension Gnomarchy used to offer wanted K and Shift+K
# for hjkl navigation. Both were set at once for a whole release: the key did
# whichever the shell happened to register last. No Gnomarchy custom keybinding
# may share an accelerator with Tiling Shell's.
collect_custom_bindings() {
  local list slot path binding
  list="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo '')"
  while read -r slot; do
    [[ -n "$slot" ]] || continue
    path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$slot/"
    binding="$(gsettings get "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path" binding 2>/dev/null || echo '')"
    binding="${binding//\'/}"
    [[ -n "$binding" && "$binding" != "@as"* ]] && echo "$binding"
  done < <(grep -oE 'custom[0-9]+' <<<"$list" | sort -u)
}

collect_tiling_bindings() {
  local schema="org.gnome.shell.extensions.tilingshell" key value
  gsettings get org.gnome.shell enabled-extensions 2>/dev/null | grep -q tilingshell || return 0
  gsettings list-schemas 2>/dev/null | grep -qx "$schema" || return 0

  while read -r key; do
    [[ -n "$key" ]] || continue
    value="$(gsettings get "$schema" "$key" 2>/dev/null || echo '')"
    # Only the keybinding keys are lists of accelerators.
    [[ "$value" == "["*"<"* ]] || continue
    tr ',' '\n' <<<"$value" | tr -d "[]' " | grep -v '^$'
  done < <(gsettings list-keys "$schema" 2>/dev/null)
}

mapfile -t custom_keys < <(collect_custom_bindings)
mapfile -t tiling_keys < <(collect_tiling_bindings)

clashes=()
for a in "${custom_keys[@]}"; do
  for b in "${tiling_keys[@]}"; do
    [[ "$a" == "$b" ]] && clashes+=("$a")
  done
done

if ((${#tiling_keys[@]} == 0)); then
  echo "INFO  no tiling extension bindings to compare against"
elif ((${#clashes[@]} == 0)); then
  ok "no Gnomarchy command shares a key with the tiling extension (${#tiling_keys[@]} checked)"
else
  no "${#clashes[@]} accelerator(s) bound twice" "${clashes[*]}"
fi

# --- Regression: Super+N switched workspace and launched an app ------------
#
# GNOME ships switch-to-application-1..9 on Super+1..9 in
# org.gnome.shell.keybindings, and Gnomarchy puts switch-to-workspace-N on the
# same keys in org.gnome.desktop.wm.keybindings -- six of them by default, all
# nine on the Omarchy profile. Every one of those keys had two handlers and did
# whichever the shell registered last. Turning Dash to Dock's hot-keys off,
# which the installer does, is a different setting and never affected this.
#
# These two schemas are where that class of defect lives, so compare them
# wholesale rather than checking the digits by name.
collect_schema_accels() {
  local schema="$1" key value
  gsettings list-schemas 2>/dev/null | grep -qx "$schema" || return 0

  while read -r key; do
    [[ -n "$key" ]] || continue
    value="$(gsettings get "$schema" "$key" 2>/dev/null || echo '')"
    # Keybinding keys are lists of accelerators; everything else is skipped.
    [[ "$value" == "["*"<"* ]] || continue
    while read -r accel; do
      [[ -n "$accel" ]] && printf '%s\t%s\n' "$accel" "$key"
    done < <(tr ',' '\n' <<<"$value" | tr -d "[]' " | grep -v '^$')
  done < <(gsettings list-keys "$schema" 2>/dev/null)
}

mapfile -t wm_accels < <(collect_schema_accels org.gnome.desktop.wm.keybindings)
mapfile -t shell_accels < <(collect_schema_accels org.gnome.shell.keybindings)

wm_shell_clashes=()
for wm_entry in "${wm_accels[@]}"; do
  for shell_entry in "${shell_accels[@]}"; do
    if [[ "${wm_entry%%$'\t'*}" == "${shell_entry%%$'\t'*}" ]]; then
      wm_shell_clashes+=("${wm_entry%%$'\t'*} (${wm_entry#*$'\t'} / ${shell_entry#*$'\t'})")
    fi
  done
done

if ((${#wm_accels[@]} == 0 || ${#shell_accels[@]} == 0)); then
  echo "INFO  could not read one of the keybinding schemas; skipping wm/shell comparison"
elif ((${#wm_shell_clashes[@]} == 0)); then
  ok "no key is claimed by both the window manager and the shell (${#wm_accels[@]} vs ${#shell_accels[@]} checked)"
else
  no "${#wm_shell_clashes[@]} key(s) claimed by both the window manager and the shell" \
    "${wm_shell_clashes[*]}"
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

# --- Boot menu: snapshots, snap-pac and the theme ---------------------------
BOOT_BIN=/usr/local/lib/gnomarchy/boot/gnomarchy-boot
LIMINE=/boot/limine.conf

limine_refs_ok() {
  local path hash bad=0
  while read -r path hash; do
    if [[ ! -f "/boot$path" || "$(b2sum "/boot$path" | cut -d' ' -f1)" != "$hash" ]]; then
      echo "      bad reference: $path"
      bad=1
    fi
  done < <(sed -nE 's/^[[:space:]]*(kernel_path|module_path): boot\(\):([^#]+)#([0-9a-f]+)$/\2 \3/p' "$LIMINE")
  return "$bad"
}

snap="$(sudo -n snapper -c root create --print-number --description 'CI session snapshot')"
if [[ "$snap" =~ ^[0-9]+$ ]] && grep -q "^///$snap | " "$LIMINE"; then
  ok "snapshot $snap, made through snapperd, is in the boot menu"
else
  no "a snapshot made through snapperd did not reach the boot menu" "snapper printed: $snap"
fi
limine_refs_ok && ok "every boot file in limine.conf matches its hash" || no "limine.conf has stale references"

pkg="$(find /var/cache/pacman/pkg -name 'file-[0-9]*.pkg.tar.zst' | sort | tail -n1)"
if [[ -n "$pkg" ]] && sudo -n pacman -U --noconfirm "$pkg"; then
  post="$(sudo -n snapper --csvout --no-headers -c root list --columns number,type |
    awk -F, '$2 == "post" { n = $1 } END { print n }')"
  if [[ -n "$post" ]] && ((post > snap)) && grep -q "^///$post | " "$LIMINE"; then
    ok "snap-pac's post snapshot $post of a pacman transaction is in the boot menu"
  else
    no "no post snapshot of the pacman transaction in the boot menu" "newest post: ${post:-none}"
  fi
else
  no "could not reinstall the file package from the cache" "${pkg:-no package found}"
fi

# shellcheck source=../../default/boot/lib/palette.sh
source "$HOME/.local/share/gnomarchy/default/boot/lib/palette.sh"
want="$(boot_palette_from_alacritty "$HOME/.local/share/gnomarchy/themes/gruvbox/alacritty.toml" |
  sed -n 's/^BACKGROUND=//p')"
gnomarchy-theme-set gruvbox >/dev/null
recoloured=0
for _ in $(seq 1 20); do
  grep -qx "term_background: 00$want" "$LIMINE" && { recoloured=1; break; }
  sleep 1
done
((recoloured)) && ok "a theme change recolours the Limine menu" ||
  no "the Limine menu kept its colours after a theme change" "$(grep '^term_background' "$LIMINE")"
gnomarchy-theme-set tokyo-night >/dev/null
# The theme change queues a menu regeneration (a path unit) that renders the
# default entry. Wait for it to land and finish, or it can run after the
# hand-over below and reset the third boot's default.
want_back="$(boot_palette_from_alacritty "$HOME/.local/share/gnomarchy/themes/tokyo-night/alacritty.toml" |
  sed -n 's/^BACKGROUND=//p')"
settled=0
for _ in $(seq 1 30); do
  if grep -qx "term_background: 00$want_back" "$LIMINE" &&
    ! systemctl is-active --quiet gnomarchy-boot-theme.service; then
    settled=1
    break
  fi
  sleep 1
done
((settled)) || no "the menu did not return to tokyo-night" "$(grep '^term_background' "$LIMINE")"

sources="$(gsettings get org.gnome.desktop.input-sources sources)"
[[ "$sources" == "[('xkb', 'de')]" ]] && ok "GNOME input sources are the installer's layout" ||
  no "GNOME input sources are not [('xkb', 'de')]" "$sources"
tz="$(timedatectl show -p Timezone --value)"
[[ "$tz" == Europe/Berlin ]] && ok "the timezone is Europe/Berlin" || no "the timezone is $tz"

# --- Windows apps: WinBoat is opt-in, its prerequisites are not -------------
# WinBoat itself is not installed here (AUR, and a Windows download), but
# what it needs from the base install is: Docker running, the user in its
# group from the first login on, FreeRDP. KVM is not checked: this session
# runs in a VM without nested virtualization.
if windows_status="$(gnomarchy windows status 2>&1)"; then
  ok "gnomarchy windows status runs"
else
  no "gnomarchy windows status failed" "$windows_status"
fi
[[ "$windows_status" == *"not installed (gnomarchy windows install)"* ]] &&
  ok "WinBoat is not installed until asked for" || no "WinBoat status is unexpected" "$windows_status"
[[ "$windows_status" == *"Docker: the service is running"* ]] &&
  ok "Docker is running for WinBoat" || no "Docker is not running" "$windows_status"
[[ "$windows_status" == *"is in the docker group"* ]] &&
  ok "the user is in the docker group in the session" || no "the session lacks the docker group" "$windows_status"

# --- The control center ----------------------------------------------------
# GJS has no compile step, so a syntax error or a bad import is invisible until
# something runs the app. An application that owns its D-Bus name has parsed
# every module and built its window, which makes this the compiler this stack
# does not otherwise have.
trace "launching the control center"
setsid gnomarchy-menu >/var/tmp/gnomarchy-gui.log 2>&1 &
gui_pid=$!

owned=0
for _ in $(seq 1 20); do
  if busctl --user list --no-legend --no-pager | grep -q org.gnomarchy.ControlCenter; then
    owned=1
    break
  fi
  sleep 1
done

if (( owned )); then
  ok "control center owns org.gnomarchy.ControlCenter"
else
  no "control center never appeared on the session bus" "$(tail -n 5 /var/tmp/gnomarchy-gui.log)"
fi

kill "$gui_pid" 2>/dev/null || true  # already gone if it crashed; not a failure

# Hand over to the third boot: the snapshot made above, which, unlike
# snapshot 1, includes CI's autologin and this script. No queued regeneration
# may follow --default, so let the theme service go idle first.
for _ in $(seq 1 30); do
  systemctl is-active --quiet gnomarchy-boot-theme.service || break
  sleep 1
done
if [[ "$snap" =~ ^[0-9]+$ ]] && sudo -n "$BOOT_BIN" update --default "snapshot:$snap" &&
  grep -q "^default_entry: Gnomarchy/Snapshots/$snap | " "$LIMINE"; then
  ok "the next boot defaults to snapshot $snap"
  echo "SNAPSHOT: $snap"
else
  no "could not make snapshot $snap the next boot's default"
fi

finish
