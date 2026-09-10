#!/bin/bash

gnomarchy_header "Publishing Gnomarchy Commands System-Wide"

# Every gnomarchy-* helper must resolve from the GNOME session, not just from
# a login shell.
#
# ~/.local/share/gnomarchy/bin reaches PATH only via /etc/profile.d and
# .bashrc, neither of which applies to the graphical session. That silently
# broke anything the session itself launches: the first-run autostart entry,
# the Super+Alt+Space menu binding and the Ctrl+Print capture binding all
# resolved to "command not found".
BIN_DIR="$GNOMARCHY_PATH/bin"

if [[ ! -d "$BIN_DIR" ]]; then
  gnomarchy_warn "No bin directory at $BIN_DIR; skipping."
  return 0 2>/dev/null || exit 0
fi

sudo mkdir -p /usr/local/bin 2>/dev/null || true

linked=0
for cmd in "$BIN_DIR"/gnomarchy*; do
  [[ -f "$cmd" ]] || continue
  chmod +x "$cmd" 2>/dev/null || true
  if sudo ln -sf "$cmd" "/usr/local/bin/$(basename "$cmd")" 2>/dev/null; then
    linked=$((linked + 1))
  fi
done

gnomarchy_step "Linked $linked Gnomarchy commands into /usr/local/bin"
