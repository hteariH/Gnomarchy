#!/bin/bash

gnomarchy_header "Installing Brave Origin (Debloated Privacy Browser)"

# 1. Attempt installation via yay (AUR brave-origin-bin) if yay is available
if command -v yay >/dev/null 2>&1; then
  echo "Installing brave-origin-bin from AUR..."
  yay -S --needed --noconfirm brave-origin-bin 2>/dev/null || true
fi

# 2. If not installed via AUR, use official Brave Origin Linux installer
if ! command -v brave-origin >/dev/null 2>&1; then
  echo "Installing Brave Origin via official distribution script..."
  curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin bash 2>/dev/null || true
fi

# 3. Fallback: If brave-origin package is unavailable, fallback to brave-bin
if ! command -v brave-origin >/dev/null 2>&1 && ! command -v brave >/dev/null 2>&1; then
  if command -v yay >/dev/null 2>&1; then
    echo "Fallback: Installing brave-bin from AUR..."
    yay -S --needed --noconfirm brave-bin 2>/dev/null || true
  fi
fi

# 4. Set Brave Origin as default xdg web browser
for desktop_file in "brave-origin.desktop" "brave-browser-origin.desktop" "brave-browser.desktop" "com.brave.Browser.desktop"; do
  if [ -f "/usr/share/applications/$desktop_file" ] || \
     [ -f "$HOME/.local/share/applications/$desktop_file" ] || \
     [ -f "/var/lib/flatpak/exports/share/applications/$desktop_file" ]; then
    xdg-settings set default-web-browser "$desktop_file" 2>/dev/null || true
    xdg-mime default "$desktop_file" x-scheme-handler/http x-scheme-handler/https text/html 2>/dev/null || true
    break
  fi
done

gnomarchy_step "Brave Origin configured as default browser"
