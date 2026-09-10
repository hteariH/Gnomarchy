#!/bin/bash

gnomarchy_header "Setting Up Extension & Developer Tooling"

# Ensure pipx path is configured
pipx ensurepath >/dev/null 2>&1 || true

# Install gnome-extensions-cli for automated extension management
if ! command -v gext >/dev/null 2>&1; then
  echo "Installing gnome-extensions-cli via pipx..."
  pipx install gnome-extensions-cli --system-site-packages >/dev/null 2>&1 || true
fi

# Ensure Mise is installed if not already available
if ! command -v mise >/dev/null 2>&1; then
  echo "Installing Mise for multi-language runtime management..."
  curl https://mise.run | sh >/dev/null 2>&1 || true
fi

# Install Paru AUR helper (pre-compiled x86_64 binary)
if ! command -v paru >/dev/null 2>&1; then
  echo "Installing Paru AUR helper..."
  mkdir -p /tmp/paru-install
  if curl -sL "https://github.com/Morganamilo/paru/releases/download/v2.1.0/paru-v2.1.0-x86_64.tar.zst" -o /tmp/paru-install/paru.tar.zst 2>/dev/null; then
    tar -xf /tmp/paru-install/paru.tar.zst -C /tmp/paru-install/ 2>/dev/null || true
    if [ -f /tmp/paru-install/paru ]; then
      sudo cp -f /tmp/paru-install/paru /usr/local/bin/paru 2>/dev/null || true
      sudo chmod +x /usr/local/bin/paru 2>/dev/null || true
    fi
  fi
  rm -rf /tmp/paru-install
fi

gnomarchy_step "Developer and extension tooling configured"
