#!/bin/bash
# Make GNOME Terminal the default terminal (Super+Return, dock, micro's
# desktop entry) and give it a Gnomarchy profile the theme engine can recolour.
# Alacritty stays installed and themed as a secondary terminal.
set -eEo pipefail

sudo pacman -S --noconfirm --needed gnome-terminal 2>/dev/null || true

GNOMARCHY_PROFILE_UUID="b1dcc9dd-5262-4d8d-a863-c897e6d979b9"
PROFILE_PATH="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$GNOMARCHY_PROFILE_UUID/"

if command -v gsettings >/dev/null 2>&1; then
  EXISTING="$(gsettings get org.gnome.Terminal.ProfilesList list 2>/dev/null || echo '@as []')"
  if [[ "$EXISTING" != *"$GNOMARCHY_PROFILE_UUID"* ]]; then
    if [[ "$EXISTING" == "@as []" || "$EXISTING" == "[]" ]]; then
      gsettings set org.gnome.Terminal.ProfilesList list "['$GNOMARCHY_PROFILE_UUID']" 2>/dev/null || true
    else
      gsettings set org.gnome.Terminal.ProfilesList list "${EXISTING%]}, '$GNOMARCHY_PROFILE_UUID']" 2>/dev/null || true
    fi
  fi

  gsettings set org.gnome.Terminal.ProfilesList default "'$GNOMARCHY_PROFILE_UUID'" 2>/dev/null || true
  gsettings set "$PROFILE_PATH" visible-name "'Gnomarchy'" 2>/dev/null || true
  gsettings set "$PROFILE_PATH" use-theme-colors false 2>/dev/null || true
  gsettings set "$PROFILE_PATH" use-system-font false 2>/dev/null || true
  gsettings set "$PROFILE_PATH" font "'JetBrainsMono Nerd Font 10'" 2>/dev/null || true
  gsettings set "$PROFILE_PATH" scrollback-lines 10000 2>/dev/null || true
  gsettings set "$PROFILE_PATH" scrollbar-policy "'never'" 2>/dev/null || true
  gsettings set "$PROFILE_PATH" audible-bell false 2>/dev/null || true
  gsettings set "$PROFILE_PATH" default-size-columns 110 2>/dev/null || true
  gsettings set "$PROFILE_PATH" default-size-rows 30 2>/dev/null || true

  # Super+Return opens GNOME Terminal.
  BINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom0/ command 'gnome-terminal' 2>/dev/null || true

  # Swap Alacritty for GNOME Terminal in the dock favourites, in place.
  FAVS="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || echo '')"
  if [[ "$FAVS" == *"alacritty.desktop"* ]]; then
    gsettings set org.gnome.shell favorite-apps \
      "${FAVS//alacritty.desktop/org.gnome.Terminal.desktop}" 2>/dev/null || true
  fi
fi

# micro's launcher should open in the new default terminal.
MICRO_DESKTOP="$HOME/.local/share/applications/micro.desktop"
if [[ -f "$MICRO_DESKTOP" ]]; then
  sed -i 's|^Exec=alacritty -e micro|Exec=gnome-terminal -- micro|' "$MICRO_DESKTOP"
fi

# Repaint the terminal with the active theme.
THEME_FILE="$HOME/.config/gnomarchy/current/theme.name"
if [[ -f "$THEME_FILE" ]] && command -v gnomarchy-theme-set >/dev/null 2>&1; then
  gnomarchy-theme-set "$(<"$THEME_FILE")" >/dev/null 2>&1 || true
fi
