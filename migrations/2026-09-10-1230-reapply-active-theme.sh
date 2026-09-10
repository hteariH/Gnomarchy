#!/bin/bash
# Re-run the active theme so the newly-supported surfaces (GTK/libadwaita CSS,
# btop.conf color_theme, the LazyVim colorscheme pin) are generated for users
# who themed their system before those existed.
set -eEo pipefail

THEME_FILE="$HOME/.config/gnomarchy/current/theme.name"
THEME="tokyo-night"
[[ -f "$THEME_FILE" ]] && THEME="$(<"$THEME_FILE")"

if command -v gnomarchy-theme-set >/dev/null 2>&1; then
  gnomarchy-theme-set "$THEME"
fi
