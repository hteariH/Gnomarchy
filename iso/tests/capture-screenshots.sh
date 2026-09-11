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
# Two phases, one boot each. Enabling dynamic tiling only takes effect once the
# shell reloads, and under Wayland that means a new session; a fresh boot is
# the most reliable way to get one. Logging out was tried and does not work -
# it kills this script along with the session, so nothing survives to continue.
# The phase is recorded in a file, which persists across the reboot.

REPORT="/var/tmp/gnomarchy-capture.txt"
STATE_DIR="$HOME/.local/state/gnomarchy"
PHASE_FILE="$STATE_DIR/capture-phase"

# Long enough that a frame grabbed every few seconds lands mid-stage.
HOLD="${GNOMARCHY_CAPTURE_HOLD:-12}"

mkdir -p "$STATE_DIR"

trace() { logger -t gnomarchy-capture -- "$*" 2>/dev/null || true; }

# Append rather than truncate: phase 2 must not erase the phase 1 transcript.
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
if (( phase > 2 )); then
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
  launched_pids=()
  sleep 4
}

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

  # The dock, the wallpaper and the extensions all land a little after the
  # session is up, and this gap also has to outlast the host pressing Escape.

  sleep 45

  echo
  echo "--- stages ---"
  stage 01-desktop

  # There is no overview stage. ShowApplications is refused the same way the
  # screenshot interface is, and the host now presses Escape early to clear
  # the overview GNOME opens on its own - so what follows is a desktop.

  # gnomarchy-menu re-execs itself into a terminal when it has no tty, which
  # is exactly the case here, so it must be backgrounded.
  launch gnomarchy menu
  stage 03-command-center
  close_launched

  launch alacritty -e btop
  stage 04-terminal-btop

  launch alacritty -e nvim "$HOME/.local/share/gnomarchy/README.md"
  stage 05-neovim
  close_launched

  launch nautilus
  stage 06-files
  close_launched

  # The theme engine is the headline feature and the one that photographs
  # best, so it gets a stage per theme with a terminal and a GTK window open -
  # both of which the switch repaints.
  launch alacritty -e btop
  launch nautilus
  n=7
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

  echo
  echo "--- enabling dynamic tiling for the phase 2 boot ---"
  gnomarchy tiling enable 2>&1 | tail -5 || echo "gnomarchy tiling enable failed"
  echo 2 > "$PHASE_FILE"

  echo
  echo "phase 1 complete"
  trace "phase 1 complete"
  power_off
  exit 0
fi

# --- phase 2: dynamic tiling, on a shell that started with it enabled -------

echo "--- waiting for the session to settle ---"
sleep 30

echo "tiling status:"
gnomarchy tiling status 2>&1 | head -6 || echo "(gnomarchy tiling status failed)"
echo

# Three windows opened one after another, so auto-tiling has something to
# place. Opening them at once tends to race the extension.
launch alacritty -e btop
launch gnome-terminal
launch nautilus
stage 11-tiling
close_launched

echo
echo "phase 2 complete"
trace "phase 2 complete"

echo 3 > "$PHASE_FILE"
power_off
