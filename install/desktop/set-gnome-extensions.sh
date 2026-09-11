#!/bin/bash

gnomarchy_header "Installing & Configuring GNOME Extensions"

EXTENSIONS=(
  "dash-to-dock@micxgx.gmail.com"
  "tactile@lundal.io"
  "just-perfection-desktop@just-perfection"
  "blur-my-shell@aunetx"
  "space-bar@luchrioh"
  "tophat@fflewddur.github.io"
  "AlphabeticalAppGrid@stuarthayhurst"
  "appindicatorsupport@rgcjonas.gmail.com"
)

# Extension files and schemas are deployed earlier by
# install-extension-files.sh, which works without a session bus. This script
# only performs the dconf writes, so it requires a live session.

# 2. Enable user extensions and activate each extension
gsettings set org.gnome.shell disable-user-extensions false 2>/dev/null || true
if command -v gnome-extensions >/dev/null 2>&1; then
  for ext in "${EXTENSIONS[@]}"; do
    gnome-extensions enable "$ext" 2>/dev/null || true
  done
fi

# 3. Configure Tactile (Option A: Omakub Grid Tiling)
if gsettings list-schemas 2>/dev/null | grep -q "org.gnome.shell.extensions.tactile"; then
  echo "  Configuring Tactile tiling grid..."
  gsettings set org.gnome.shell.extensions.tactile col-0 1 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.tactile col-1 2 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.tactile col-2 1 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.tactile col-3 0 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.tactile row-0 1 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.tactile row-1 1 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.tactile gap-size 18 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.tactile show-tiles "['<Super>t']" 2>/dev/null || true
fi

# 4. Configure Just Perfection
if gsettings list-schemas 2>/dev/null | grep -q "org.gnome.shell.extensions.just-perfection"; then
  gsettings set org.gnome.shell.extensions.just-perfection animation 2 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.just-perfection dash-app-running true 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.just-perfection workspace true 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.just-perfection workspace-popup false 2>/dev/null || true
fi

# 5. Configure Blur My Shell
if gsettings list-schemas 2>/dev/null | grep -q "org.gnome.shell.extensions.blur-my-shell"; then
  gsettings set org.gnome.shell.extensions.blur-my-shell.overview blur true 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.blur-my-shell.overview pipeline 'pipeline_default' 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.blur-my-shell.panel blur false 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.blur-my-shell.lockscreen blur false 2>/dev/null || true
fi

# 6. Configure Space Bar (Clean numeric workspaces)
if gsettings list-schemas 2>/dev/null | grep -q "org.gnome.shell.extensions.space-bar"; then
  gsettings set org.gnome.shell.extensions.space-bar.behavior smart-workspace-names false 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.space-bar.shortcuts enable-activate-workspace-shortcuts false 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.space-bar.shortcuts enable-move-to-workspace-shortcuts true 2>/dev/null || true
fi

# 7. Configure TopHat (Minimal top bar system metrics)
if gsettings list-schemas 2>/dev/null | grep -q "org.gnome.shell.extensions.tophat"; then
  gsettings set org.gnome.shell.extensions.tophat show-icons false 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.tophat show-cpu true 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.tophat show-mem true 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.tophat show-disk false 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.tophat network-usage-unit bits 2>/dev/null || true
fi

# 8. Configure Alphabetical App Grid (Clean native launcher)
if gsettings list-schemas 2>/dev/null | grep -q "org.gnome.shell.extensions.alphabetical-app-grid"; then
  gsettings set org.gnome.shell.extensions.alphabetical-app-grid folder-order-position 'end' 2>/dev/null || true
fi

# 9. Configure Dash to Dock (Ubuntu-style left side panel)
if gsettings list-schemas 2>/dev/null | grep -q "org.gnome.shell.extensions.dash-to-dock"; then
  echo "  Configuring Dash to Dock (Ubuntu style on left edge)..."
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT' 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.dash-to-dock extend-height true 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.dash-to-dock intellihide false 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 38 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts false 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.dash-to-dock multi-monitor true 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.dash-to-dock show-apps-at-top false 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.dash-to-dock running-indicator-style 'DOTS' 2>/dev/null || true
  gsettings set org.gnome.shell.extensions.dash-to-dock hot-keys false 2>/dev/null || true
fi

# 10. Configure Pinned Dock Favorites (Ubuntu / Developer layout)
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
  'org.gnome.Terminal.desktop', \
  'org.gnome.Nautilus.desktop', \
  'code-oss.desktop', \
  'io.github.kolunmi.Bazaar.desktop', \
  'org.gnome.Settings.desktop' \
]" 2>/dev/null || true

gnomarchy_step "GNOME extensions installed and pre-configured"
