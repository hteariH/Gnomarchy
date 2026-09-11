#!/bin/bash

# In-guest screenshot capture.
#
# Runs inside the installed system's graphical session, the same way
# verify-session.sh does, and for the same reason: a screenshot of the desktop
# can only be taken by something living in a session with a D-Bus bus.
#
# It deliberately does NOT use `gnomarchy capture`. That wraps grim + slurp,
# which need wlr-screencopy and wlr-layer-shell - wlroots protocols Mutter does
# not implement - and its gnome-screenshot fallback is not in the package list.
# The one mechanism that works under GNOME is the shell's own D-Bus interface.
#
# Two phases, because enabling dynamic tiling only takes effect after the shell
# reloads, and under Wayland that means logging out. Phase 1 shoots everything
# else, turns tiling on and logs out; autologin brings us back into phase 2,
# which shoots the tiled layout and powers off. The phase is recorded in a file
# so the same autostart entry serves both.
#
# Results land in /var/tmp/gnomarchy-screenshots/ and a transcript in
# /var/tmp/gnomarchy-capture.txt, which CI reads off the disk image afterwards.

SHOT_DIR="/var/tmp/gnomarchy-screenshots"
REPORT="/var/tmp/gnomarchy-capture.txt"
STATE_DIR="$HOME/.local/state/gnomarchy"
PHASE_FILE="$STATE_DIR/capture-phase"

mkdir -p "$SHOT_DIR" "$STATE_DIR"

trace() { logger -t gnomarchy-capture -- "$*" 2>/dev/null || true; }

# Append rather than truncate: phase 2 must not erase the phase 1 transcript.
exec >>"$REPORT" 2>&1

phase="$(cat "$PHASE_FILE" 2>/dev/null || echo 1)"
trace "capture started, phase=$phase, session=${XDG_SESSION_TYPE:-unknown}"

echo "=== capture phase $phase ==="
echo "date: $(date -Is)"
echo "session type: ${XDG_SESSION_TYPE:-unknown}"
echo "user: $(whoami)"
echo

# A logout that never lands in phase 2 would otherwise loop forever.
if (( phase > 2 )); then
  echo "phase $phase is past the end - powering off"
  sudo -n systemctl poweroff 2>/dev/null || systemctl poweroff 2>/dev/null
  exit 0
fi

shots_taken=0
shots_failed=0

# Take one screenshot. Never fatal: a step that cannot be shot should cost one
# frame, not the whole run, and the reason belongs in the transcript so the
# next CI run can be aimed rather than guessed.
shot() {
  local name="$1" path="$SHOT_DIR/$name.png" out
  if out="$(gdbus call --session \
        --dest org.gnome.Shell \
        --object-path /org/gnome/Shell/Screenshot \
        --method org.gnome.Shell.Screenshot.Screenshot \
        false false "$path" 2>&1)"; then
    if [[ -s "$path" ]]; then
      echo "SHOT  $name ($(stat -c%s "$path") bytes)"
      trace "shot $name ok"
      shots_taken=$((shots_taken + 1))
      return 0
    fi
    echo "MISS  $name -- call returned [$out] but the file is empty or absent"
  else
    echo "MISS  $name -- $out"
  fi
  trace "shot $name failed"
  shots_failed=$((shots_failed + 1))
  return 1
}

# Launch a windowed program and remember it, so the frame can be cleared
# before the next one is composed.
launched_pids=()
launch() {
  setsid "$@" >/dev/null 2>&1 &
  launched_pids+=("$!")
  trace "launched: $*"
}

close_launched() {
  local pid
  for pid in "${launched_pids[@]}"; do
    kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  done
  launched_pids=()
  sleep 3
}

if [[ "$phase" == "1" ]]; then
  # first-run is an autostart entry too, and everything worth photographing -
  # the theme, the dock, the keybindings - is what it writes. Shooting before
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

  # Let the shell settle: the dock, the wallpaper and the extensions all land
  # a little after the session is technically up.
  sleep 20

  # Which shell methods this GNOME actually exposes. The screenshot API has
  # moved between releases and the overview has no stable public call at all,
  # so record the truth here rather than guessing again next run.
  echo
  echo "--- org.gnome.Shell methods ---"
  gdbus introspect --session --dest org.gnome.Shell \
    --object-path /org/gnome/Shell 2>&1 | grep -E "^ +[A-Z][A-Za-z]*\(" || echo "(introspection failed)"
  echo "--- org.gnome.Shell.Screenshot methods ---"
  gdbus introspect --session --dest org.gnome.Shell \
    --object-path /org/gnome/Shell/Screenshot 2>&1 | grep -E "^ +[A-Z][A-Za-z]*\(" || echo "(introspection failed)"
  echo

  echo "--- frames ---"
  shot 01-desktop

  # The overview has no supported D-Bus entry point, so try the candidates in
  # order and log which one answered. There is no Eval fallback: it works only
  # when unsafe-mode is on, which it is not by default.
  overview_method=""
  for m in ShowApplications FocusSearch; do
    if gdbus call --session --dest org.gnome.Shell \
         --object-path /org/gnome/Shell \
         --method "org.gnome.Shell.$m" >/dev/null 2>&1; then
      overview_method="$m"
      break
    fi
  done
  if [[ -n "$overview_method" ]]; then
    echo "overview opened via $overview_method"
    sleep 4
    shot 02-overview
    gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
      --method "org.gnome.Shell.$overview_method" >/dev/null 2>&1 || true
    sleep 3
  else
    echo "SKIP  02-overview -- no shell method would open the overview"
  fi

  # The command center. gnomarchy-menu re-execs itself into a terminal when it
  # has no tty, which is exactly the case here, so it must be backgrounded.
  launch gnomarchy menu
  sleep 10
  shot 03-command-center
  close_launched

  launch alacritty -e btop
  sleep 8
  shot 04-terminal-btop

  launch alacritty -e nvim "$HOME/.local/share/gnomarchy/README.md"
  sleep 12
  shot 05-neovim
  close_launched

  launch nautilus
  sleep 8
  shot 06-files
  close_launched

  # The theme engine is the headline feature and the one that photographs
  # best, so it gets a frame per theme with a terminal and a GTK window open -
  # both of which the switch repaints.
  launch alacritty -e btop
  launch nautilus
  sleep 8
  n=7
  for theme in kanagawa gruvbox rose-pine catppuccin-latte; do
    if gnomarchy theme set "$theme" >/dev/null 2>&1; then
      sleep 8
      shot "$(printf '%02d' $n)-theme-$theme"
    else
      echo "MISS  theme $theme -- gnomarchy theme set failed"
      shots_failed=$((shots_failed + 1))
    fi
    n=$((n + 1))
  done
  close_launched

  gnomarchy theme set tokyo-night >/dev/null 2>&1 || true

  echo
  echo "--- enabling dynamic tiling and logging out for phase 2 ---"
  gnomarchy tiling enable 2>&1 | tail -5 || echo "gnomarchy tiling enable failed"
  echo 2 > "$PHASE_FILE"
  sync

  echo "phase 1 complete: $shots_taken taken, $shots_failed failed"
  trace "phase 1 complete: $shots_taken taken, $shots_failed failed"

  gnome-session-quit --logout --no-prompt >/dev/null 2>&1 || true

  # If the logout did not take, do not strand the VM until the CI timeout -
  # the phase 1 frames are already on disk and worth more than a hung run.
  sleep 90
  echo "logout did not end the session; powering off with phase 1 frames only"
  sudo -n systemctl poweroff 2>/dev/null || systemctl poweroff 2>/dev/null
  exit 0
fi

# --- phase 2: dynamic tiling ------------------------------------------------

echo "--- waiting for the reloaded shell to settle ---"
sleep 25

echo "tiling status:"
gnomarchy tiling status 2>&1 | head -5 || echo "(gnomarchy tiling status failed)"
echo

# Three windows opened one after another, so auto-tiling has something to
# place. Opening them at once tends to race the extension.
launch alacritty -e btop
sleep 5
launch gnome-terminal
sleep 5
launch nautilus
sleep 8
shot 11-tiling
close_launched

echo
echo "phase 2 complete: $shots_taken taken, $shots_failed failed"
echo
echo "=== frames on disk ==="
ls -la "$SHOT_DIR" 2>&1
echo
echo "RESULT: $([[ -n "$(ls -1 "$SHOT_DIR"/*.png 2>/dev/null)" ]] && echo SUCCESS || echo FAILURE)"
trace "capture finished"

echo 3 > "$PHASE_FILE"
sync

sudo -n systemctl poweroff 2>/dev/null || systemctl poweroff 2>/dev/null
