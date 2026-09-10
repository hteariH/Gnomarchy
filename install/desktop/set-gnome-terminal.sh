#!/bin/bash

gnomarchy_header "Configuring GNOME Terminal"

# Gnomarchy owns a dedicated GNOME Terminal profile with a fixed UUID, so the
# theme engine always knows which profile to recolour. Using a fixed id also
# means re-running the installer reconfigures rather than duplicates it.
GNOMARCHY_PROFILE_UUID="b1dcc9dd-5262-4d8d-a863-c897e6d979b9"
PROFILE_PATH="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$GNOMARCHY_PROFILE_UUID/"

if ! command -v gsettings >/dev/null 2>&1; then
  gnomarchy_step "gsettings unavailable - skipping GNOME Terminal setup"
  return 0 2>/dev/null || exit 0
fi

# Register the profile in the profile list if it is not already there.
EXISTING="$(gsettings get org.gnome.Terminal.ProfilesList list 2>/dev/null || echo '@as []')"
if [[ "$EXISTING" != *"$GNOMARCHY_PROFILE_UUID"* ]]; then
  if [[ "$EXISTING" == "@as []" || "$EXISTING" == "[]" ]]; then
    gsettings set org.gnome.Terminal.ProfilesList list "['$GNOMARCHY_PROFILE_UUID']" 2>/dev/null || true
  else
    gsettings set org.gnome.Terminal.ProfilesList list \
      "${EXISTING%]}, '$GNOMARCHY_PROFILE_UUID']" 2>/dev/null || true
  fi
fi

gsettings set org.gnome.Terminal.ProfilesList default "'$GNOMARCHY_PROFILE_UUID'" 2>/dev/null || true

gsettings set "$PROFILE_PATH" visible-name "'Gnomarchy'" 2>/dev/null || true

# Colors are owned by the theme engine, so opt out of the GTK theme colors.
gsettings set "$PROFILE_PATH" use-theme-colors false 2>/dev/null || true
gsettings set "$PROFILE_PATH" use-transparent-background true 2>/dev/null || true
gsettings set "$PROFILE_PATH" background-transparency-percent 4 2>/dev/null || true

# Typography: match the rest of the desktop rather than the GNOME default.
gsettings set "$PROFILE_PATH" use-system-font false 2>/dev/null || true
gsettings set "$PROFILE_PATH" font "'JetBrainsMono Nerd Font 10'" 2>/dev/null || true

gsettings set "$PROFILE_PATH" scrollback-lines 10000 2>/dev/null || true
gsettings set "$PROFILE_PATH" scrollbar-policy "'never'" 2>/dev/null || true
gsettings set "$PROFILE_PATH" audible-bell false 2>/dev/null || true
gsettings set "$PROFILE_PATH" cursor-shape "'block'" 2>/dev/null || true
gsettings set "$PROFILE_PATH" cursor-blink-mode "'on'" 2>/dev/null || true
gsettings set "$PROFILE_PATH" default-size-columns 110 2>/dev/null || true
gsettings set "$PROFILE_PATH" default-size-rows 30 2>/dev/null || true

# Chrome-free window to match the rest of the desktop.
gsettings set org.gnome.Terminal.Legacy.Settings headerbar true 2>/dev/null || true
gsettings set org.gnome.Terminal.Legacy.Settings default-show-menubar false 2>/dev/null || true
gsettings set org.gnome.Terminal.Legacy.Settings new-terminal-mode "'tab'" 2>/dev/null || true

gnomarchy_step "GNOME Terminal profile configured"
