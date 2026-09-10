#!/bin/bash

gnomarchy_header "Initializing Default Gnomarchy Theme"

mkdir -p "$HOME/.config/gnomarchy/themes"

# 1. Install system-wide wallpapers into /usr/share/backgrounds/gnomarchy
echo "Installing Gnomarchy wallpapers to system..."
sudo mkdir -p /usr/share/backgrounds/gnomarchy 2>/dev/null || true
for bg in "$GNOMARCHY_PATH"/themes/*/backgrounds/*; do
  if [ -f "$bg" ]; then
    sudo cp -f "$bg" /usr/share/backgrounds/gnomarchy/ 2>/dev/null || true
  fi
done

# 2. Initialize default theme (Tokyo Night)
if command -v gnomarchy-theme-set >/dev/null 2>&1; then
  gnomarchy-theme-set "tokyo-night" || true
elif [ -f "$GNOMARCHY_PATH/bin/gnomarchy-theme-set" ]; then
  "$GNOMARCHY_PATH/bin/gnomarchy-theme-set" "tokyo-night" || true
fi

gnomarchy_step "Tokyo Night theme initialized"
