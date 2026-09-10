#!/bin/bash

gnomarchy_header "Installing Brave Origin (Debloated Privacy Browser)"

# 1. Primary: Install official Brave Origin binary via GitHub Release installer
if ! command -v brave-origin >/dev/null 2>&1 && ! command -v brave >/dev/null 2>&1; then
  echo "Installing official Brave Origin release binary..."
  sudo python3 "$GNOMARCHY_INSTALL/packaging/install-brave.py" || true
fi

# 2. Secondary Fallback: Install via Paru AUR helper if available
if ! command -v brave-origin >/dev/null 2>&1 && ! command -v brave >/dev/null 2>&1; then
  if command -v paru >/dev/null 2>&1; then
    echo "Fallback: Installing brave-bin from AUR via paru..."
    paru -S --needed --noconfirm brave-bin 2>/dev/null || true
  elif command -v yay >/dev/null 2>&1; then
    echo "Fallback: Installing brave-bin from AUR via yay..."
    yay -S --needed --noconfirm brave-bin 2>/dev/null || true
  fi
fi

# 3. Tertiary Fallback: Install via Flatpak
if ! command -v brave-origin >/dev/null 2>&1 && ! command -v brave >/dev/null 2>&1; then
  if command -v flatpak >/dev/null 2>&1; then
    echo "Fallback: Installing Brave Browser via Flatpak..."
    flatpak install -y --noninteractive flathub com.brave.Browser 2>/dev/null || true
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
