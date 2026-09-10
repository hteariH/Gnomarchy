#!/bin/bash
# Repair machines installed from the ISO before the first-run mechanism existed.
#
# The desktop installer ran inside arch-chroot, where there is no D-Bus session
# bus, so every gsettings write was discarded. Custom keybindings (Super+Return,
# Super+D, Super+Escape, Super+Alt+Space, Ctrl+Print) cannot be expressed as
# gschema overrides, so they were missing entirely. Dock favorites also listed
# three Brave desktop ids, which showed a duplicate icon when more than one
# existed.
set -eEo pipefail

# Hide the compatibility alias so Brave stops appearing twice.
for dir in /usr/share/applications "$HOME/.local/share/applications"; do
  alias_file="$dir/brave-browser.desktop"
  [[ -f "$alias_file" ]] || continue
  grep -q '^NoDisplay=true' "$alias_file" && continue
  # Only hide it when it is the Origin alias, not a real separate install.
  grep -q 'brave-origin' "$alias_file" || continue
  if [[ -w "$alias_file" ]]; then
    printf 'NoDisplay=true\n' >> "$alias_file"
  else
    printf 'NoDisplay=true\n' | sudo tee -a "$alias_file" >/dev/null
  fi
done

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
sudo update-desktop-database /usr/share/applications 2>/dev/null || true

# Apply everything that needs a session bus. When run without one (for example
# from a TTY), schedule it for the next graphical login instead.
if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" || -S "/run/user/$(id -u)/bus" ]]; then
  command -v gnomarchy-first-run >/dev/null 2>&1 && gnomarchy-first-run || true
else
  mkdir -p "$HOME/.config/autostart"
  cat > "$HOME/.config/autostart/gnomarchy-first-run.desktop" <<'AUTOSTART'
[Desktop Entry]
Type=Application
Name=Gnomarchy First Run Setup
Comment=Applies Gnomarchy desktop settings and keyboard shortcuts
Exec=/usr/local/bin/gnomarchy first-run
Icon=preferences-desktop
Terminal=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Applications
NoDisplay=true
AUTOSTART
  echo "No session bus; desktop configuration scheduled for next login."
fi
