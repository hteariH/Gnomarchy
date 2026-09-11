#!/bin/bash

gnomarchy_header "Applying Curated GNOME Settings"

# Window management & Mutter
gsettings set org.gnome.mutter center-new-windows true
gsettings set org.gnome.mutter attach-modal-dialogs true
gsettings set org.gnome.mutter edge-tiling true

# Use 6 fixed workspaces instead of dynamic workspaces (developer standard)
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 6

# Typography
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10'
gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans 10'
gsettings set org.gnome.desktop.interface font-name 'Noto Sans 10'

# Icons
# papirus-icon-theme is installed by the package list; before this it was
# never applied, so the setting stayed on Adwaita and the theme was dead
# weight on every install. The dark variant is the baseline because 18 of the
# 22 themes are dark; gnomarchy-theme-set moves it with the theme from here.
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

# Calendar & Time
gsettings set org.gnome.desktop.calendar show-weekdate true
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.interface clock-show-date true

# Hardware & Power optimizations
gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'

# Touchpad gestures & feel
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true

# Color & Night Light
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 4000

gnomarchy_step "GNOME settings successfully applied"
