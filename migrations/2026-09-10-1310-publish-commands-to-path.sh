#!/bin/bash
# Only the `gnomarchy` dispatcher was linked into /usr/local/bin. Every other
# gnomarchy-* helper lived solely in ~/.local/share/gnomarchy/bin, which
# reaches PATH via /etc/profile.d and .bashrc -- neither of which applies to
# the GNOME session. Anything the session launched itself therefore failed
# silently: the first-run autostart entry, the Super+Alt+Space menu binding
# and the Ctrl+Print capture binding.
set -eEo pipefail

GNOMARCHY_PATH="${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}"
BIN_DIR="$GNOMARCHY_PATH/bin"

[[ -d "$BIN_DIR" ]] || exit 0

sudo mkdir -p /usr/local/bin 2>/dev/null || true
for cmd in "$BIN_DIR"/gnomarchy*; do
  [[ -f "$cmd" ]] || continue
  chmod +x "$cmd" 2>/dev/null || true
  sudo ln -sf "$cmd" "/usr/local/bin/$(basename "$cmd")" 2>/dev/null || true
done

# Re-point the autostart entry at an absolute path so it cannot depend on PATH.
AUTOSTART="$HOME/.config/autostart/gnomarchy-first-run.desktop"
if [[ -f "$AUTOSTART" ]]; then
  sed -i 's|^Exec=gnomarchy-first-run$|Exec=/usr/local/bin/gnomarchy first-run|' "$AUTOSTART"
fi

# Move any flat wallpapers into the per-theme layout the theme engine resolves.
BG="/usr/share/backgrounds/gnomarchy"
if [[ -d "$BG" ]] && compgen -G "$BG/*.*" >/dev/null 2>&1; then
  for file in "$BG"/*.*; do
    [[ -f "$file" ]] || continue
    theme="$(basename "${file%.*}")"
    if [[ -d "$GNOMARCHY_PATH/themes/$theme" ]]; then
      sudo mkdir -p "$BG/$theme"
      sudo mv -f "$file" "$BG/$theme/" 2>/dev/null || true
    fi
  done
fi
