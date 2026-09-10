#!/bin/bash
# The Ctrl+Print binding called gnome-screenshot, which was never installed.
# Replace it with the grim/slurp-backed gnomarchy-capture, and add the
# Super+Alt+Space command center binding.
set -eEo pipefail

sudo pacman -S --noconfirm --needed grim slurp 2>/dev/null || true

BINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"

gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
  "['$BINDING_PATH/custom0/', '$BINDING_PATH/custom1/', '$BINDING_PATH/custom2/', '$BINDING_PATH/custom3/', '$BINDING_PATH/custom4/', '$BINDING_PATH/custom5/', '$BINDING_PATH/custom6/']"

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom3/ name 'Annotate Screenshot'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom3/ command 'gnomarchy-capture annotate'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom3/ binding '<Control>Print'

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom6/ name 'Gnomarchy Menu'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom6/ command 'gnomarchy-menu'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom6/ binding '<Super><Alt>space'
