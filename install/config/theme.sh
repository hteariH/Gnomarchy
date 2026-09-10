#!/bin/bash

gnomarchy_header "Initializing Default Gnomarchy Theme"

mkdir -p "$HOME/.config/gnomarchy/themes"
mkdir -p "$HOME/.config/gnomarchy/backgrounds"

# 1. Install the bundled SVG wallpapers, one directory per theme. These are
#    generated in-repo and act as the offline fallback when the upstream
#    download below is unavailable.
echo "Installing bundled fallback wallpapers..."
sudo mkdir -p /usr/share/backgrounds/gnomarchy 2>/dev/null || true
for theme_dir in "$GNOMARCHY_PATH"/themes/*/; do
  theme_name="$(basename "$theme_dir")"
  for bg in "$theme_dir"backgrounds/*; do
    [ -f "$bg" ] || continue
    sudo mkdir -p "/usr/share/backgrounds/gnomarchy/$theme_name" 2>/dev/null || true
    sudo cp -f "$bg" "/usr/share/backgrounds/gnomarchy/$theme_name/" 2>/dev/null || true
  done
done
sudo chmod -R 755 /usr/share/backgrounds/gnomarchy 2>/dev/null || true
sudo find /usr/share/backgrounds/gnomarchy -type f -exec chmod 644 {} + 2>/dev/null || true

# 2. Fetch the upstream Omarchy wallpapers onto this machine. Gnomarchy does
#    not redistribute them; see BACKGROUNDS.md. A failure here is not fatal --
#    the SVG fallbacks installed above keep every theme usable offline.
if command -v gnomarchy-backgrounds >/dev/null 2>&1; then
  gnomarchy-backgrounds || echo "  Background download skipped; using bundled fallbacks."
elif [ -x "$GNOMARCHY_PATH/bin/gnomarchy-backgrounds" ]; then
  "$GNOMARCHY_PATH/bin/gnomarchy-backgrounds" || echo "  Background download skipped; using bundled fallbacks."
fi

# 3. Initialize default theme (Tokyo Night)
if command -v gnomarchy-theme-set >/dev/null 2>&1; then
  gnomarchy-theme-set "tokyo-night" || true
elif [ -f "$GNOMARCHY_PATH/bin/gnomarchy-theme-set" ]; then
  "$GNOMARCHY_PATH/bin/gnomarchy-theme-set" "tokyo-night" || true
fi

gnomarchy_step "Tokyo Night theme initialized"
