#!/bin/bash
# Apply the icon theme the distribution already installs.
#
# papirus-icon-theme has been in gnomarchy-base.packages all along, but nothing
# ever set org.gnome.desktop.interface icon-theme, so every machine stayed on
# Adwaita and the package was dead weight. From now on the baseline is set with
# the rest of the curated GNOME settings and gnomarchy-theme-set moves it with
# the theme; this brings machines that are already installed into line.
#
# The variant follows the active theme rather than being fixed: Papirus ships
# Papirus, Papirus-Dark and Papirus-Light, which differ in their panel and
# folder tones, and a dark desktop on Papirus-Light reads as a mismatch.
set -eEo pipefail

if ! command -v gsettings >/dev/null 2>&1; then
  echo "gsettings is unavailable; leaving the icon theme alone."
  exit 0
fi

# Install the theme if this machine predates it being in the package list.
if [[ ! -d /usr/share/icons/Papirus ]]; then
  sudo pacman -S --noconfirm --needed papirus-icon-theme || {
    echo "Could not install papirus-icon-theme; leaving the icon theme alone."
    exit 0
  }
fi

# Which variant the active theme calls for. Themes carry a light.mode marker
# file; everything without one is dark.
GNOMARCHY_PATH="${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}"
THEME_NAME="$(cat "$HOME/.config/gnomarchy/current/theme.name" 2>/dev/null || echo "")"
VARIANT="Papirus-Dark"
if [[ -n "$THEME_NAME" && -f "$GNOMARCHY_PATH/themes/$THEME_NAME/light.mode" ]]; then
  VARIANT="Papirus-Light"
fi

if [[ ! -d "/usr/share/icons/$VARIANT" ]]; then
  echo "$VARIANT is not present; leaving the icon theme alone."
  exit 0
fi

CURRENT="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")"
if [[ "$CURRENT" == "$VARIANT" ]]; then
  echo "Icon theme is already $VARIANT."
  exit 0
fi

gsettings set org.gnome.desktop.interface icon-theme "$VARIANT"
echo "Icon theme set to $VARIANT (was ${CURRENT:-unset})."
exit 0
