#!/bin/bash

gnomarchy_header "Installing & Configuring GNOME Extensions"

EXTENSIONS=(
  "tactile@lundal.io"
  "just-perfection-desktop@just-perfection"
  "blur-my-shell@aunetx"
  "space-bar@luchrioh"
  "tophat@fflewddur.github.io"
  "AlphabeticalAppGrid@stuarthayhurst"
  "appindicatorsupport@rgcjonas.gmail.com"
  "dash-to-dock@micxgx.gmail.com"
)

# Install extensions via gnome-extensions-cli
for ext in "${EXTENSIONS[@]}"; do
  echo "  Installing extension: $ext"
  if command -v gext >/dev/null 2>&1; then
    gext install "$ext" 2>/dev/null || true
    gnome-extensions enable "$ext" 2>/dev/null || true
  fi
done

# Copy any available extension schemas into system schemas for gsettings access
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
if [ -d "$EXT_DIR" ]; then
  for schema_dir in "$EXT_DIR"/*/schemas; do
    if [ -d "$schema_dir" ]; then
      sudo cp -f "$schema_dir"/*.gschema.xml /usr/share/glib-2.0/schemas/ 2>/dev/null || true
    fi
  done
  sudo glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true
fi

# Configure Tactile (Option A: Omakub Grid Tiling)
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.tactile"; then
  echo "  Configuring Tactile tiling grid..."
  gsettings set org.gnome.shell.extensions.tactile col-0 1
  gsettings set org.gnome.shell.extensions.tactile col-1 2
  gsettings set org.gnome.shell.extensions.tactile col-2 1
  gsettings set org.gnome.shell.extensions.tactile col-3 0
  gsettings set org.gnome.shell.extensions.tactile row-0 1
  gsettings set org.gnome.shell.extensions.tactile row-1 1
  gsettings set org.gnome.shell.extensions.tactile gap-size 18
  gsettings set org.gnome.shell.extensions.tactile show-tiles "['<Super>t']"
fi

# Configure Just Perfection
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.just-perfection"; then
  gsettings set org.gnome.shell.extensions.just-perfection animation 2
  gsettings set org.gnome.shell.extensions.just-perfection dash-app-running true
  gsettings set org.gnome.shell.extensions.just-perfection workspace true
  gsettings set org.gnome.shell.extensions.just-perfection workspace-popup false
fi

# Configure Blur My Shell
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.blur-my-shell"; then
  gsettings set org.gnome.shell.extensions.blur-my-shell.overview blur true
  gsettings set org.gnome.shell.extensions.blur-my-shell.overview pipeline 'pipeline_default'
  gsettings set org.gnome.shell.extensions.blur-my-shell.panel blur false
  gsettings set org.gnome.shell.extensions.blur-my-shell.lockscreen blur false
fi

# Configure Space Bar (Clean numeric workspaces)
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.space-bar"; then
  gsettings set org.gnome.shell.extensions.space-bar.behavior smart-workspace-names false
  gsettings set org.gnome.shell.extensions.space-bar.shortcuts enable-activate-workspace-shortcuts false
  gsettings set org.gnome.shell.extensions.space-bar.shortcuts enable-move-to-workspace-shortcuts true
fi

# Configure TopHat (Minimal top bar system metrics)
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.tophat"; then
  gsettings set org.gnome.shell.extensions.tophat show-icons false
  gsettings set org.gnome.shell.extensions.tophat show-cpu true
  gsettings set org.gnome.shell.extensions.tophat show-mem true
  gsettings set org.gnome.shell.extensions.tophat show-disk false
  gsettings set org.gnome.shell.extensions.tophat network-usage-unit bits
fi

# Configure Alphabetical App Grid (Option B: Native launcher organized cleanly)
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.alphabetical-app-grid"; then
  gsettings set org.gnome.shell.extensions.alphabetical-app-grid folder-order-position 'end'
fi

# Configure Dash to Dock (Ubuntu-style left side panel)
if gsettings list-schemas | grep -q "org.gnome.shell.extensions.dash-to-dock"; then
  echo "  Configuring Dash to Dock (Ubuntu style on left edge)..."
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT'
  gsettings set org.gnome.shell.extensions.dash-to-dock extend-height true
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true
  gsettings set org.gnome.shell.extensions.dash-to-dock intellihide false
  gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 38
  gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false
  gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts false
  gsettings set org.gnome.shell.extensions.dash-to-dock multi-monitor true
  gsettings set org.gnome.shell.extensions.dash-to-dock show-apps-at-top false
  gsettings set org.gnome.shell.extensions.dash-to-dock running-indicator-style 'DOTS'
  gsettings set org.gnome.shell.extensions.dash-to-dock hot-keys false
fi

# Configure Pinned Dock Favorites (Ubuntu / Developer layout)
BROWSER_DESKTOP="brave-origin.desktop"
if [ -f "/usr/share/applications/brave-browser-origin.desktop" ]; then
  BROWSER_DESKTOP="brave-browser-origin.desktop"
elif [ -f "/usr/share/applications/brave-origin.desktop" ]; then
  BROWSER_DESKTOP="brave-origin.desktop"
elif [ -f "/usr/share/applications/brave-browser.desktop" ]; then
  BROWSER_DESKTOP="brave-browser.desktop"
elif [ -f "/var/lib/flatpak/exports/share/applications/com.brave.Browser.desktop" ]; then
  BROWSER_DESKTOP="com.brave.Browser.desktop"
fi

gsettings set org.gnome.shell favorite-apps "[ \
  '$BROWSER_DESKTOP', \
  'alacritty.desktop', \
  'org.gnome.Nautilus.desktop', \
  'micro.desktop', \
  'io.github.kolunmi.Bazaar.desktop', \
  'org.gnome.Settings.desktop' \
]" 2>/dev/null || true

gnomarchy_step "GNOME extensions installed and pre-configured"
