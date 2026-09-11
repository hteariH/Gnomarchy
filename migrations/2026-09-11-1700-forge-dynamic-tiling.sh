#!/bin/bash
# Dynamic tiling never tiled dynamically, and the manual mode was redundant.
#
# The dynamic backend was Tiling Shell with enable-autotiling on. Its
# auto-tiling places a new window into a fixed tile of a static layout and
# leaves every window already on screen exactly where it is. With its default
# layout (22% | 56% | 22%, the side columns halved) and its "closest vacant
# tile to the centre" rule, the first window landed in the 56% centre tile and
# the second in a 22%-wide sliver, with the first one untouched. That is the
# extension working as designed -- but the README, the manual and `gnomarchy
# tiling` all promised neighbours that resize to fit.
#
# So the two modes are now:
#
#   dynamic  Forge, which tiles into a binary tree: a new window splits the
#            focused one, both halves resize, and closing a window returns its
#            space to its sibling. The build is the jcrussell fork, which
#            declares GNOME 50; the Forge on extensions.gnome.org stops at 49
#            and would not load at all.
#
#   manual   Tiling Shell with auto-placement off, which is what it is good at:
#            zones you pick by dragging, snap assist, keyboard throws.
#
# Tactile did a strict subset of manual-mode Tiling Shell and is no longer
# shipped. Its files are left in place; it is only disabled.
#
# Idempotent: deploying files that are already there and re-setting dconf keys
# that already hold these values changes nothing.
set -eEo pipefail

GNOMARCHY_PATH="${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}"
FORGE_UUID="forge@jmmaranan.com"
TS_UUID="tilingshell@ferrarodomenico.com"
TACTILE_UUID="tactile@lundal.io"
USER_EXT="$HOME/.local/share/gnome-shell/extensions"
TS="org.gnome.shell.extensions.tilingshell"

# --- 1. Deploy Forge ------------------------------------------------------
# Filesystem work, valid with or without a session.
zip="$GNOMARCHY_PATH/default/gnome/extensions/$FORGE_UUID.zip"
if [[ ! -f "$zip" ]]; then
  echo "  No bundled Forge zip at $zip; run 'gnomarchy update' first." >&2
  exit 1
fi

command -v unzip >/dev/null 2>&1 || {
  echo "  unzip is unavailable; cannot deploy Forge." >&2
  exit 1
}

mkdir -p "$USER_EXT/$FORGE_UUID"
unzip -oq "$zip" -d "$USER_EXT/$FORGE_UUID"
echo "  Deployed Forge to $USER_EXT/$FORGE_UUID"

schema_dir="$USER_EXT/$FORGE_UUID/schemas"
if [[ -d "$schema_dir" ]] && [[ ! -f "$schema_dir/gschemas.compiled" ]] &&
  command -v glib-compile-schemas >/dev/null 2>&1; then
  glib-compile-schemas "$schema_dir"
fi

# --- 2. Everything below is a dconf write ---------------------------------
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && ! -S "/run/user/$(id -u)/bus" ]]; then
  echo "  No session bus: Forge is deployed, but the switch has to happen from"
  echo "  inside a desktop session. Run: gnomarchy tiling enable"
  exit 0
fi

command -v gsettings >/dev/null 2>&1 || exit 0

enabled="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || echo '')"

# Was this machine using the old dynamic mode? That is Tiling Shell enabled
# *and* auto-tiling on -- Tiling Shell enabled with auto-tiling off is the new
# manual mode and must not be mistaken for it.
was_dynamic=false
if [[ "$enabled" == *tilingshell* ]]; then
  auto="$(gsettings get "$TS" enable-autotiling 2>/dev/null || echo false)"
  [[ "$auto" == "true" ]] && was_dynamic=true
fi

# --- 3. Tactile retires -----------------------------------------------------
if [[ "$enabled" == *tactile* ]] && command -v gnome-extensions >/dev/null 2>&1; then
  gnome-extensions disable "$TACTILE_UUID" 2>/dev/null || true
  echo "  Disabled Tactile; manual tiling is Tiling Shell now."
  echo "  Its files are still in $USER_EXT if you want it back."
fi

if [[ "$was_dynamic" == true ]]; then
  echo "  This machine runs dynamic tiling; moving it from Tiling Shell to Forge."
  if command -v gnomarchy-tiling >/dev/null 2>&1; then
    # One source of truth for the configuration: the command that sets it up.
    # It enables Forge, disables Tiling Shell, and moves Super+K out of the way
    # of hjkl navigation.
    gnomarchy-tiling enable
  else
    echo "  gnomarchy-tiling is not on PATH; run 'gnomarchy tiling enable' by hand." >&2
    exit 0
  fi
else
  echo "  Setting Tiling Shell up as the manual mode (auto-placement off)."
  if command -v gnomarchy-tiling >/dev/null 2>&1; then
    gnomarchy-tiling disable
  else
    echo "  gnomarchy-tiling is not on PATH; run 'gnomarchy tiling disable' by hand." >&2
    exit 0
  fi
fi

echo "  Log out and back in to load the change."
