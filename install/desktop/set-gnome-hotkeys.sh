#!/bin/bash

gnomarchy_header "Configuring Developer Keyboard Shortcuts"

# Window Management Hotkeys
gsettings set org.gnome.desktop.wm.keybindings close "['<Super>w']"
gsettings set org.gnome.desktop.wm.keybindings maximize "['<Super>Up']"
gsettings set org.gnome.desktop.wm.keybindings begin-resize "['<Super>BackSpace']"
gsettings set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Shift>F11']"

# Both tiling modes throw a window with Super+Shift+arrows, which is GNOME's
# default for move-to-monitor. Move that one modifier further out rather than
# leave two handlers on one accelerator; `gnomarchy tiling` keeps it there.
gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-left "['<Super><Control><Shift>Left']"
gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-right "['<Super><Control><Shift>Right']"
gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-up "['<Super><Control><Shift>Up']"
gsettings set org.gnome.desktop.wm.keybindings move-to-monitor-down "['<Super><Control><Shift>Down']"

# Workspace Switching: Super + 1-6
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>1']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>2']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>3']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-4 "['<Super>4']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-5 "['<Super>5']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-6 "['<Super>6']"

# GNOME Shell binds switch-to-application-1..9 to Super+1..9 by default, so
# every Super+N above was claimed twice and did whichever handler the shell
# registered last. Give the keys Gnomarchy claims to the workspaces and leave
# the rest with GNOME. (Dash to Dock's own hot-keys are turned off separately;
# that setting does not touch the Shell's.)
for n in 1 2 3 4 5 6; do
  gsettings set org.gnome.shell.keybindings "switch-to-application-$n" "@as []"
done
for n in 7 8 9; do
  gsettings reset org.gnome.shell.keybindings "switch-to-application-$n"
done

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
  "['$BINDING_PATH/custom0/', '$BINDING_PATH/custom1/', '$BINDING_PATH/custom2/', '$BINDING_PATH/custom3/', '$BINDING_PATH/custom4/', '$BINDING_PATH/custom5/', '$BINDING_PATH/custom6/', '$BINDING_PATH/custom7/', '$BINDING_PATH/custom8/']"

# 1. Terminal (Super + Return)
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom0/ name 'Terminal'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom0/ command 'gnome-terminal'
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
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom3/ command 'gnomarchy-capture annotate'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom3/ binding '<Control>Print'

# 5. Voxtype AI Speech-to-Text Dictation (Super + D)
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom4/ name 'Voxtype AI Dictation'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom4/ command 'gnomarchy voxtype toggle'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom4/ binding '<Super>d'

# 6. Retro Terminal Screensaver (Super + Escape)
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom5/ name 'Retro Screensaver'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom5/ command 'gnomarchy screensaver'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom5/ binding '<Super>Escape'

# 7. Gnomarchy Command Center Menu (Super + Alt + Space)
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom6/ name 'Gnomarchy Menu'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom6/ command 'gnomarchy-menu'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom6/ binding '<Super><Alt>space'

# 8. Searchable Keybindings (Super + K)
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom7/ name 'Keybindings'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom7/ command 'gnomarchy-keybindings'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom7/ binding '<Super>k'

# 9. The Manual (Super + Shift + K)
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom8/ name 'Manual'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom8/ command 'gnomarchy-manual'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/custom8/ binding '<Super><Shift>k'

gnomarchy_step "Developer hotkeys established"
