#!/bin/bash

gnomarchy_header "Configuring Flatpak & Installing Bazaar App Store"

if command -v flatpak >/dev/null 2>&1; then
  # 1. Enable Flathub Remote
  echo "Enabling Flathub repository..."
  sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
  flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

  # 2. Install Bazaar Flatpak App Store
  echo "Installing Bazaar (Flatpak App Store)..."
  flatpak install -y --noninteractive flathub io.github.kolunmi.Bazaar 2>/dev/null || true

  gnomarchy_step "Flatpak and Bazaar successfully installed"
else
  gnomarchy_warn "Flatpak is not installed. Skipping Flatpak and Bazaar configuration."
fi
