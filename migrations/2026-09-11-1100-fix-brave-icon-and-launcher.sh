#!/bin/bash
# The dock entry for Brave did not launch and its icon was broken.
#
# Two causes. The installer chose the launch target from ["brave",
# "brave-browser", "brave-origin"] in that order, so /usr/local/bin/brave-origin
# pointed at the 300 MB browser binary instead of the small brave-origin
# wrapper that starts it in Origin mode. And it installed whichever
# product_logo_*.png os.walk returned first into hicolor/128x128, so a 16x16
# image was routinely presented as a 128x128 icon.
set -eEo pipefail

BRAVE_DIR="/opt/brave-origin"
[[ -d "$BRAVE_DIR" ]] || exit 0

# Point the launcher at the Origin wrapper when it exists.
if [[ -f "$BRAVE_DIR/brave-origin" ]]; then
  sudo chmod 755 "$BRAVE_DIR/brave-origin" 2>/dev/null || true
  for link in /usr/local/bin/brave-origin /usr/local/bin/brave /usr/local/bin/brave-browser; do
    sudo ln -sf "$BRAVE_DIR/brave-origin" "$link" 2>/dev/null || true
  done
  echo "Launcher now points at the Brave Origin wrapper."
fi

# Install every icon size into the directory that matches it.
installed=0
for png in "$BRAVE_DIR"/product_logo_*.png; do
  [[ -f "$png" ]] || continue
  size="$(basename "$png" .png)"
  size="${size#product_logo_}"
  [[ "$size" =~ ^[0-9]+$ ]] || continue
  target="/usr/share/icons/hicolor/${size}x${size}/apps"
  sudo mkdir -p "$target" 2>/dev/null || continue
  sudo cp -f "$png" "$target/brave-origin.png" 2>/dev/null && installed=$((installed + 1))
done

if ((installed > 0)); then
  largest="$(ls "$BRAVE_DIR"/product_logo_*.png 2>/dev/null |
    sed 's/.*product_logo_\([0-9]*\)\.png/\1 &/' | sort -rn | head -1 | cut -d' ' -f2-)"
  if [[ -n "$largest" ]]; then
    sudo mkdir -p /usr/share/pixmaps
    sudo cp -f "$largest" /usr/share/pixmaps/brave-origin.png 2>/dev/null || true
    sudo cp -f "$largest" /usr/share/pixmaps/brave-browser.png 2>/dev/null || true
  fi
  sudo gtk-update-icon-cache -qtf /usr/share/icons/hicolor 2>/dev/null || true
  echo "Installed $installed Brave icon size(s)."
fi

sudo update-desktop-database /usr/share/applications 2>/dev/null || true
exit 0
