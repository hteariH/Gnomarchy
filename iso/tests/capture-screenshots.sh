#!/bin/bash

# In-guest half of the screenshot capture: compose the desktop, hold each
# arrangement still, and say in the transcript exactly when it was on screen.
#
# It takes no pictures. The first version tried, through
# org.gnome.Shell.Screenshot, and every call came back with
#
#   org.freedesktop.DBus.Error.AccessDenied: Screenshot is not allowed
#
# which is policy rather than a bug: since GNOME 41 the shell only answers that
# interface for a fixed allowlist of senders - gnome-settings-daemon and the
# xdg-desktop-portal backends. A script in the session is not on it and cannot
# get on it, because those well-known names are already owned. The portal route
# needs a permission granted through a dialog nobody is there to click.
#
# So the pictures are taken from outside, by QEMU itself: the host dumps the
# video framebuffer on a timer while this script drives the desktop. See
# iso/tests/capture-host.sh. That is also the more honest image - it is the
# actual video output of the real Wayland session, not a reconstruction.
#
# Frames are matched to stages by wall clock, which is why every stage prints a
# timestamp and then holds still for HOLD seconds.
#
# One boot. There used to be a second, for dynamic tiling, which only took
# effect once the shell reloaded. The phase file stays so that a guest which
# boots again after the capture powers off instead of shooting it twice.

REPORT="/var/tmp/gnomarchy-capture.txt"
STATE_DIR="$HOME/.local/state/gnomarchy"
PHASE_FILE="$STATE_DIR/capture-phase"

# Long enough that a frame grabbed every few seconds lands mid-stage.
HOLD="${GNOMARCHY_CAPTURE_HOLD:-12}"

mkdir -p "$STATE_DIR"

trace() { logger -t gnomarchy-capture -- "$*" 2>/dev/null || true; }

# Append rather than truncate: a second boot must not erase the transcript.
exec >>"$REPORT" 2>&1

phase="$(cat "$PHASE_FILE" 2>/dev/null || echo 1)"
trace "capture started, phase=$phase, session=${XDG_SESSION_TYPE:-unknown}"

echo "=== capture phase $phase ==="
echo "date: $(date -Is)"
echo "session type: ${XDG_SESSION_TYPE:-unknown}"
echo "user: $(whoami)"
echo "hold per stage: ${HOLD}s"
echo

# Guard against a phase file that never advances.
if (( phase > 1 )); then
  echo "phase $phase is past the end - powering off"
  sudo -n systemctl poweroff 2>/dev/null || systemctl poweroff 2>/dev/null
  exit 0
fi

power_off() {
  echo
  echo "powering off at $(date -Is)"
  sync
  sudo -n systemctl poweroff 2>/dev/null || systemctl poweroff 2>/dev/null
}

# first-run announces itself with notify-send, and a banner raised while the
# overview is up never times out - one sat across the top of every frame of the
# last run. Turning banners off covers anything that has not fired yet, and
# closing ids one by one covers whatever is already on screen.
dismiss_notifications() {
  gsettings set org.gnome.desktop.notifications show-banners false 2>/dev/null || true
  local id
  for id in $(seq 1 30); do
    gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.CloseNotification "$id" >/dev/null 2>&1 || true
  done
}

# Whether the shell actually loaded the extensions, as opposed to dconf simply
# saying it should have. dconf reports an extension as enabled whether or not
# the shell could load it.
report_extensions() {
  echo "--- extensions the shell is running ---"
  gnome-extensions list --enabled 2>&1 || echo "(gnome-extensions list failed)"
  local uuid
  for uuid in tilingshell@ferrarodomenico.com dash-to-dock@micxgx.gmail.com; do
    echo "$uuid: $(gnome-extensions info "$uuid" 2>&1 | tr "
" " " | sed -e "s/  */ /g")"
  done
  echo
}

# Announce an arrangement and hold it. The timestamps are the whole point:
# they are what tells the host which frames are worth keeping.
stage() {
  local name="$1"
  echo "STAGE $name  start=$(date -Is)"
  sleep "$HOLD"
  echo "STAGE $name  end=$(date -Is)"
  trace "stage $name held ${HOLD}s"
}

launched_pids=()
launch() {
  setsid "$@" >/dev/null 2>&1 &
  launched_pids+=("$!")
  trace "launched: $*"
  sleep 6
}

close_launched() {
  local pid
  for pid in "${launched_pids[@]}"; do
    kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  done
  # GNOME Terminal's windows belong to gnome-terminal-server, not to the client
  # launched above, so they close when the program inside them exits. Nothing
  # to end is the normal case for every other stage.
  pkill -x btop || true
  pkill -x nvim || true
  launched_pids=()
  sleep 4
}

dismiss_notifications

if [[ "$phase" == "1" ]]; then
  # first-run is an autostart entry too, and everything worth photographing -
  # the theme, the dock, the keybindings - is what it writes. Composing before
  # it finishes photographs a stock GNOME desktop.
  echo "--- waiting for first-run ---"
  for i in $(seq 1 36); do
    [[ -f "$STATE_DIR/first-run.done" ]] && break
    sleep 5
  done
  if [[ -f "$STATE_DIR/first-run.done" ]]; then
    echo "first-run completed"
  else
    echo "WARNING: first-run never completed; frames will show an unconfigured desktop"
  fi

  # Whatever first-run raised on its way past.
  dismiss_notifications

  # The dock, the wallpaper and the extensions all land a little after the
  # session is up, and this gap also has to outlast the host pressing Escape.

  sleep 45

  echo
  report_extensions
  echo "--- stages ---"
  stage 01-desktop

  # There is no overview stage. ShowApplications is refused the same way the
  # screenshot interface is, and the host now presses Escape early to clear
  # the overview GNOME opens on its own - so what follows is a desktop.

  # The three commands open the control center on their own page and fall
  # back to a re-exec into a terminal when there is no tty, so each is
  # backgrounded the same way the old single-page menu was.
  launch gnomarchy-menu
  stage 03-control-center-menu

  launch gnomarchy-keybindings
  stage 04-control-center-keybindings

  launch gnomarchy-manual
  stage 05-control-center-manual
  close_launched

  launch gnome-terminal --wait -- btop
  stage 06-terminal-btop

  launch gnome-terminal --wait -- nvim "$HOME/.local/share/gnomarchy/README.md"
  stage 07-neovim
  close_launched

  launch nautilus
  stage 08-files
  close_launched

  # The theme engine is the headline feature and the one that photographs
  # best, so it gets a stage per theme with a terminal and a GTK window open -
  # both of which the switch repaints.
  launch gnome-terminal --wait -- btop
  launch nautilus
  n=9
  for theme in kanagawa gruvbox rose-pine catppuccin-latte; do
    if gnomarchy theme set "$theme" >/dev/null 2>&1; then
      sleep 6
      stage "$(printf '%02d' $n)-theme-$theme"
    else
      echo "MISS  theme $theme -- gnomarchy theme set failed"
    fi
    n=$((n + 1))
  done
  close_launched

  gnomarchy theme set tokyo-night >/dev/null 2>&1 || true

  echo 2 > "$PHASE_FILE"

  echo
  echo "phase 1 complete"
  trace "phase 1 complete"
  power_off
  exit 0
fi
