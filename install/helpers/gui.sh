#!/bin/bash

# Launching the control center, with an honest fallback.
#
# The GUI is the face of these three commands, but it must never be the only
# way in: over SSH, in a TTY, and on the half-installed system where the
# troubleshooting page matters most, there is no display and possibly no gjs.
# In those cases this returns non-zero and the caller uses its text path.

gnomarchy_launch_gui() {
  local page="$1"
  local root="${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}"
  local entry="$root/gui/src/main.js"

  [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]] || return 1
  command -v gjs >/dev/null || return 1
  [[ -f "$entry" ]] || return 1

  exec gjs -m "$entry" "--page=$page"
}
