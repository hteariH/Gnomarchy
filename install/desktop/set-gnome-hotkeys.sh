#!/bin/bash

gnomarchy_header "Configuring Developer Keyboard Shortcuts"

# Window Management Hotkeys
gsettings set org.gnome.desktop.wm.keybindings close "['<Super>w']"
gsettings set org.gnome.desktop.wm.keybindings maximize "['<Super>Up']"
gsettings set org.gnome.desktop.wm.keybindings begin-resize "['<Super>BackSpace']"
gsettings set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Shift>F11']"

# Workspace Switching: Super + 1-6
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>1']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>2']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>3']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-4 "['<Super>4']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-5 "['<Super>5']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-6 "['<Super>6']"

# Move Window to Workspace: Super + Shift + 1-6
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-1 "['<Super><Shift>1']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-2 "['<Super><Shift>2']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-3 "['<Super><Shift>3']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-4 "['<Super><Shift>4']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-5 "['<Super><Shift>5']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-6 "['<Super><Shift>6']"

# Media Key Adjustments
gsettings set org.gnome.settings-daemon.plugins.media-keys next "['<Shift>AudioPlay']"

# Custom Keybindings Slot Setup
BINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
  "['$BINDING_PATH/custom0/', '$BINDING_PATH/custom1/', '$BINDING_PATH/custom2/', '$BINDING_PATH/custom3/', '$BINDING_PATH/custom4/', '$BINDING_PATH/custom5/']"

# 1. Terminal (Super + Return)
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom0/ name 'Terminal'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom0/ command 'alacritty'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom0/ binding '<Super>Return'

# 2. Browser (Super + B) - Brave Origin
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom1/ name 'Brave Origin'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom1/ command 'sh -c "command -v brave-origin >/dev/null && exec brave-origin || command -v brave >/dev/null && exec brave || command -v brave-browser >/dev/null && exec brave-browser || flatpak run com.brave.Browser >/dev/null 2>&1 || exec chromium || exec xdg-open https://"'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom1/ binding '<Super>b'

# 3. File Manager (Super + E)
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom2/ name 'Files'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom2/ command 'nautilus'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom2/ binding '<Super>e'

# 4. Satty Annotation Screenshot (Ctrl + Print)
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom3/ name 'Annotate Screenshot'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom3/ command 'gnome-screenshot -a -f /tmp/satty-shot.png && satty -f /tmp/satty-shot.png'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom3/ binding '<Control>Print'

# 5. Voxtype AI Speech-to-Text Dictation (Super + D)
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom4/ name 'Voxtype AI Dictation'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom4/ command 'gnomarchy voxtype toggle'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom4/ binding '<Super>d'

# 6. Retro Terminal Screensaver (Super + Escape)
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom5/ name 'Retro Screensaver'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom5/ command 'gnomarchy screensaver'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom5/ binding '<Super>Escape'

gnomarchy_step "Developer hotkeys established"
