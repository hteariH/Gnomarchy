#!/bin/bash

gnomarchy_header "Initializing Default Gnomarchy Theme"

mkdir -p "$HOME/.config/gnomarchy/themes"

# Initialize to Tokyo Night default theme
if command -v gnomarchy-theme-set >/dev/null 2>&1; then
  gnomarchy-theme-set "tokyo-night" || true
elif [ -f "$GNOMARCHY_PATH/bin/gnomarchy-theme-set" ]; then
  "$GNOMARCHY_PATH/bin/gnomarchy-theme-set" "tokyo-night" || true
fi

gnomarchy_step "Tokyo Night theme initialized"
