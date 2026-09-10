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

gnomarchy_step "Developer and extension tooling configured"
