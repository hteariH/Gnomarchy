#!/bin/bash
# Move to per-theme wallpaper directories and fetch the upstream Omarchy
# wallpapers onto this machine. Previously every theme shipped only a generated
# SVG placeholder, installed flat into /usr/share/backgrounds/gnomarchy/.
set -eEo pipefail

GNOMARCHY_PATH="${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}"
TARGET="/usr/share/backgrounds/gnomarchy"

sudo mkdir -p "$TARGET" 2>/dev/null || true

# Re-lay the bundled SVG fallbacks into per-theme subdirectories.
for theme_dir in "$GNOMARCHY_PATH"/themes/*/; do
  theme_name="$(basename "$theme_dir")"
  for bg in "$theme_dir"backgrounds/*; do
    [ -f "$bg" ] || continue
    sudo mkdir -p "$TARGET/$theme_name" 2>/dev/null || true
    sudo cp -f "$bg" "$TARGET/$theme_name/" 2>/dev/null || true
  done
done

# Remove the old flat copies now that per-theme directories exist.
sudo find "$TARGET" -maxdepth 1 -type f -delete 2>/dev/null || true

sudo chmod -R 755 "$TARGET" 2>/dev/null || true
sudo find "$TARGET" -type f -exec chmod 644 {} + 2>/dev/null || true

mkdir -p "$HOME/.config/gnomarchy/backgrounds"

# Fetch upstream wallpapers. Not fatal: the SVG fallbacks above keep every
# theme usable if there is no network.
if command -v gnomarchy-backgrounds >/dev/null 2>&1; then
  gnomarchy-backgrounds || echo "Background download skipped; bundled fallbacks remain in place."
fi

# Repoint the current theme at its new wallpaper.
THEME_FILE="$HOME/.config/gnomarchy/current/theme.name"
if [[ -f "$THEME_FILE" ]] && command -v gnomarchy-theme-set >/dev/null 2>&1; then
  gnomarchy-theme-set "$(<"$THEME_FILE")" >/dev/null 2>&1 || true
fi
