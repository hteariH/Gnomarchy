#!/bin/bash
# Extensions were deployed without compiling their own schemas directory.
#
# GNOME Shell resolves an extension's settings through
# <extension>/schemas/gschemas.compiled. The installer compiled only the
# system schema directory, so every extension carrying settings failed to load
# with GLib.FileError -- Tactile, Blur my Shell, Just Perfection, Space Bar and
# Alphabetical App Grid. Only those whose upstream zip already shipped a
# compiled schema worked.
set -eEo pipefail

command -v glib-compile-schemas >/dev/null 2>&1 || exit 0

compiled=0
for ext_base in "$HOME/.local/share/gnome-shell/extensions" \
  /usr/share/gnome-shell/extensions; do
  [[ -d "$ext_base" ]] || continue

  for ext_dir in "$ext_base"/*/; do
    schema_dir="$ext_dir/schemas"
    [[ -d "$schema_dir" ]] || continue
    compgen -G "$schema_dir/*.gschema.xml" >/dev/null 2>&1 || continue
    [[ -f "$schema_dir/gschemas.compiled" ]] && continue

    if [[ -w "$schema_dir" ]]; then
      glib-compile-schemas "$schema_dir" 2>/dev/null && compiled=$((compiled + 1))
    else
      sudo glib-compile-schemas "$schema_dir" 2>/dev/null && compiled=$((compiled + 1))
    fi
  done
done

if ((compiled > 0)); then
  echo "Compiled schemas for $compiled extension(s)."
  echo "Log out and back in to load them."
fi
