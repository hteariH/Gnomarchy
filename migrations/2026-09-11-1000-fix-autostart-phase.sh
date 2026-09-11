#!/bin/bash
# The first-run autostart entry set X-GNOME-Autostart-Phase=Applications.
#
# GNOME 50 runs XDG autostart through systemd-xdg-autostart-generator, which
# skips any entry declaring a startup phase, because phases cannot be expressed
# as systemd units. The entry was therefore never executed, which is why
# keyboard shortcuts, the dock position and the terminal palette were not
# applied on a fresh install and `gnomarchy first-run` had to be run by hand.
set -eEo pipefail

fixed=0
for entry in "$HOME/.config/autostart"/*.desktop; do
  [[ -f "$entry" ]] || continue
  grep -q '^X-GNOME-Autostart-Phase' "$entry" || continue
  # Only touch Gnomarchy's own entries; another application's are its business.
  grep -q 'gnomarchy' "$entry" || continue
  sed -i '/^X-GNOME-Autostart-Phase/d' "$entry"
  fixed=$((fixed + 1))
done

((fixed > 0)) && echo "Repaired $fixed Gnomarchy autostart entry/entries."

# If the desktop was never configured, schedule it for the next login now that
# the entry will actually run.
STAMP="${XDG_STATE_HOME:-$HOME/.local/state}/gnomarchy/first-run.done"
AUTOSTART="$HOME/.config/autostart/gnomarchy-first-run.desktop"

if [[ ! -f "$STAMP" && ! -f "$AUTOSTART" ]]; then
  mkdir -p "$HOME/.config/autostart"
  cat > "$AUTOSTART" <<'AUTOSTART_EOF'
[Desktop Entry]
Type=Application
Name=Gnomarchy First Run Setup
Comment=Applies Gnomarchy desktop settings and keyboard shortcuts
Exec=/usr/local/bin/gnomarchy first-run
Icon=preferences-desktop
Terminal=false
X-GNOME-Autostart-enabled=true
NoDisplay=true
AUTOSTART_EOF
  echo "Scheduled desktop configuration for the next login."
fi

exit 0
