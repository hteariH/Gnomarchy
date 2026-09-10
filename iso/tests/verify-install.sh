#!/bin/bash

# Offline verification of an installed Gnomarchy system.
#
# Runs on the CI host against the installed disk image, mounted read-only at
# $ROOT. Every check here corresponds to a defect that reached a release
# because CI only ever verified that the ISO *builds*, never that it installs.
#
# Usage: verify-install.sh /mnt/gnomarchy-root
set -uo pipefail

ROOT="${1:?usage: verify-install.sh <mounted-root>}"
USER_NAME="${GNOMARCHY_TEST_USER:-citest}"
HOME_DIR="$ROOT/home/$USER_NAME"

pass=0
fail=0

ok() {
  printf '  \033[0;32mPASS\033[0m  %s\n' "$1"
  pass=$((pass + 1))
}

no() {
  printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"
  [[ -n "${2:-}" ]] && printf '        %s\n' "$2"
  fail=$((fail + 1))
}

echo "=== Offline verification of installed system ==="
echo

# --- The system booted-to state -------------------------------------------
dm_unit="$ROOT/etc/systemd/system/display-manager.service"
if [[ -e "$dm_unit" ]]; then
  dm_target="$(readlink "$dm_unit" 2>/dev/null || cat "$dm_unit" 2>/dev/null)"
  case "$dm_target" in
    *gdm*) ok "GDM is the enabled display manager" ;;
    *) no "display-manager is not GDM" "resolves to ${dm_target:-unknown}" ;;
  esac
else
  no "No display manager enabled" "expected /etc/systemd/system/display-manager.service"
fi

[[ -e "$ROOT/usr/bin/gnome-shell" ]] &&
  ok "gnome-shell installed" ||
  no "gnome-shell missing"

# --- Regression: whisper.cpp vs whisper-cpp (aborted the whole install) ----
if [[ -e "$ROOT/usr/bin/whisper-cli" ]]; then
  ok "whisper-cli present (Voxtype backend)"
else
  no "whisper-cli missing" "the whisper-cpp package did not install"
fi

# --- Regression: only the dispatcher reached the session PATH --------------
missing_links=()
for cmd in gnomarchy gnomarchy-first-run gnomarchy-menu gnomarchy-capture \
  gnomarchy-theme-set gnomarchy-backgrounds gnomarchy-migrate; do
  [[ -e "$ROOT/usr/local/bin/$cmd" ]] || missing_links+=("$cmd")
done
if ((${#missing_links[@]} == 0)); then
  ok "all session-critical commands are in /usr/local/bin"
else
  no "commands missing from /usr/local/bin" "${missing_links[*]}"
fi

# --- Regression: ISO deployed without .git, so updates were impossible -----
if [[ -d "$HOME_DIR/.local/share/gnomarchy/.git" ]]; then
  ok "Gnomarchy checkout has a git repository (updates possible)"
else
  no "no .git in ~/.local/share/gnomarchy" "this machine could never update"
fi

# --- Regression: flat wallpaper layout never matched the theme engine ------
BG="$ROOT/usr/share/backgrounds/gnomarchy"
if [[ -d "$BG/tokyo-night" ]]; then
  ok "wallpapers use the per-theme directory layout"
else
  no "no per-theme wallpaper directory" "expected $BG/tokyo-night/"
fi

if [[ -d "$BG" ]]; then
  flat_count="$(find "$BG" -maxdepth 1 -type f | wc -l)"
  ((flat_count == 0)) &&
    ok "no stray wallpapers in the flat layout" ||
    no "$flat_count wallpaper(s) still in the flat layout"

  downloaded="$(find "$BG" -type f \( -name '*.webp' -o -name '*.jpg' \) | wc -l)"
  if ((downloaded >= 80)); then
    ok "upstream wallpapers downloaded ($downloaded files)"
  else
    no "only $downloaded upstream wallpapers present" "expected ~92"
  fi
fi

# --- Regression: two identical Brave entries in the dash -------------------
alias_file="$ROOT/usr/share/applications/brave-browser.desktop"
if [[ -f "$alias_file" ]]; then
  grep -q '^NoDisplay=true' "$alias_file" &&
    ok "Brave compatibility alias is hidden from the launcher" ||
    no "brave-browser.desktop is visible" "this shows a duplicate Brave icon"
else
  ok "no Brave alias desktop entry to duplicate"
fi

visible_browsers=0
for f in "$ROOT/usr/share/applications"/*brave*.desktop; do
  [[ -f "$f" ]] || continue
  grep -q '^NoDisplay=true' "$f" || visible_browsers=$((visible_browsers + 1))
done
((visible_browsers <= 1)) &&
  ok "exactly $visible_browsers visible Brave entry" ||
  no "$visible_browsers visible Brave entries" "the dash will show duplicates"

# --- Regression: autostart Exec depended on a PATH the session lacks -------
AUTOSTART="$HOME_DIR/.config/autostart/gnomarchy-first-run.desktop"
if [[ -f "$AUTOSTART" ]]; then
  if grep -q '^Exec=/' "$AUTOSTART"; then
    ok "first-run autostart uses an absolute Exec path"
  else
    no "first-run autostart Exec is not absolute" "$(grep '^Exec=' "$AUTOSTART")"
  fi
else
  no "first-run autostart entry missing" "expected $AUTOSTART"
fi

# --- Tool configs the theme engine writes into -----------------------------
[[ -f "$HOME_DIR/.config/alacritty/alacritty.toml" ]] &&
  ok "Alacritty base config deployed" ||
  no "Alacritty base config missing"

if [[ -f "$HOME_DIR/.config/btop/btop.conf" ]]; then
  grep -q 'color_theme *= *"current"' "$HOME_DIR/.config/btop/btop.conf" &&
    ok "btop selects the Gnomarchy theme" ||
    no "btop.conf does not select the current theme"
else
  no "btop.conf missing"
fi

[[ -f "$HOME_DIR/.config/nvim/lua/config/lazy.lua" ]] &&
  ok "LazyVim bootstrap deployed" ||
  no "LazyVim bootstrap missing" "per-theme neovim.lua files would be inert"

echo
echo "=== $pass passed, $fail failed ==="
((fail == 0))
