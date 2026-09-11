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

# The browser is installed by its own stage rather than from the package
# list, and lands under any of three names depending on which route worked -
# the official release binary, brave-bin from the AUR, or the Flatpak.
browser_command() {
  if command -v brave-origin >/dev/null 2>&1; then
    echo "brave-origin"
  elif command -v brave >/dev/null 2>&1; then
    echo "brave"
  elif flatpak info com.brave.Browser >/dev/null 2>&1; then
    echo "flatpak run com.brave.Browser"
  fi
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

# Something for the editor to show. A blank VS Code window photographs as a
# grey rectangle.
HELLO="$HOME/hello.py"
cat > "$HELLO" <<'PYEOF'
def main():
    print("Hello from Gnomarchy")


if __name__ == "__main__":
    main()
PYEOF

# Neither application can be talked out of its welcome screen by a flag, so
# each is started once here, off stage, and killed. What they want to say on
# a fresh profile they say to nobody, and the profile they leave behind is
# the one the photographed window opens with.
browser="$(browser_command)"
echo "warming profiles"
if [[ -n "$browser" ]]; then
  setsid $browser --no-first-run --password-store=basic >/dev/null 2>&1 &
  sleep 25
  pkill -f brave >/dev/null 2>&1 || true
fi
setsid code --disable-workspace-trust --password-store=basic >/dev/null 2>&1 &
sleep 25
  pkill -f "code --disable-workspace-trust" >/dev/null 2>&1 || true
pkill -x code >/dev/null 2>&1 || true
sleep 5

# VS Code opens on a welcome tab and asks about Copilot on a fresh profile.
# The first is a setting; the second belongs to an extension, so the
# extension is what has to be off - by name, because --disable-extensions
# would take the language grammars with it and leave the file grey.
mkdir -p "$HOME/.config/Code/User"
cat > "$HOME/.config/Code/User/settings.json" <<'JSONEOF'
{
  "workbench.startupEditor": "none",
  "telemetry.telemetryLevel": "off",
  "update.mode": "none",
  "workbench.tips.enabled": false
}
JSONEOF

# btop refuses to draw below 80 columns, and the pane it was given last time
# was 395px - 52 columns even at font size 9. No font size fixes that; the
# terminal has to be the large pane instead, and auto-tiling gives that to
# whichever window arrives first.
launch alacritty -o font.size=9 -e btop
sleep 10

launch code --disable-workspace-trust --password-store=basic --disable-extension GitHub.copilot --disable-extension GitHub.copilot-chat "$HELLO"
sleep 20

if [[ -n "$browser" ]]; then
  # Unquoted on purpose: the Flatpak route is three words, not one.
  launch $browser --new-window --no-first-run --no-default-browser-check --password-store=basic https://gnomarchy.pages.dev
  sleep 20
else
  echo "MISS  browser -- no brave-origin, brave or com.brave.Browser found"
  launch nautilus
fi

stage 11-tiling
close_launched

echo
echo "phase 2 complete"
trace "phase 2 complete"

echo 3 > "$PHASE_FILE"
power_off
