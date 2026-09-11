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

# The installer puts /home and /var/log on their own btrfs subvolumes. If the
# caller mounted only @, those are empty directories and every check against
# them fails for a reason that has nothing to do with the install. Refuse to
# report that as a result.
if [[ ! -d "$HOME_DIR" ]]; then
  echo "  ABORT  \$HOME_DIR does not exist."
  echo "         The @home subvolume is probably not mounted; mount it before"
  echo "         running this, or every home check below is meaningless."
  exit 2
fi

if [[ ! -d "$ROOT/var/log" ]] || [[ -z "$(ls -A "$ROOT/var/log" 2>/dev/null)" ]]; then
  echo "  NOTE   $ROOT/var/log is empty - the @var_log subvolume may not be"
  echo "         mounted, so the install log will not be visible."
  echo
fi

# --- The system booted-to state -------------------------------------------
# Note on symlinks: this image is mounted under $ROOT, so an absolute symlink
# inside it resolves against the *host* filesystem and -e reports false even
# when the link is perfectly correct. Test with -L and read the target instead
# of following it.
dm_unit="$ROOT/etc/systemd/system/display-manager.service"
if [[ -L "$dm_unit" || -f "$dm_unit" ]]; then
  dm_target="$(readlink "$dm_unit" 2>/dev/null || cat "$dm_unit" 2>/dev/null)"
  case "$dm_target" in
    *gdm*) ok "GDM is the enabled display manager" ;;
    *) no "display-manager is not GDM" "resolves to ${dm_target:-unknown}" ;;
  esac
else
  no "No display manager enabled" "expected /etc/systemd/system/display-manager.service"
fi

[[ -e "$ROOT/usr/bin/gnome-shell" || -L "$ROOT/usr/bin/gnome-shell" ]] &&
  ok "gnome-shell installed" ||
  no "gnome-shell missing"

# --- Regression: whisper.cpp vs whisper-cpp (aborted the whole install) ----
if [[ -e "$ROOT/usr/bin/whisper-cli" || -L "$ROOT/usr/bin/whisper-cli" ]]; then
  ok "whisper-cli present (Voxtype backend)"
else
  no "whisper-cli missing" "the whisper-cpp package did not install"
fi

# --- Regression: only the dispatcher reached the session PATH --------------
missing_links=()
link=""
for cmd in gnomarchy gnomarchy-first-run gnomarchy-menu gnomarchy-capture \
  gnomarchy-theme-set gnomarchy-backgrounds gnomarchy-migrate; do
  link="$ROOT/usr/local/bin/$cmd"
  [[ -L "$link" || -f "$link" ]] || missing_links+=("$cmd")
done
if ((${#missing_links[@]} == 0)); then
  ok "all session-critical commands are in /usr/local/bin"
else
  no "commands missing from /usr/local/bin" "${missing_links[*]}"
fi

# --- Regression: ISO deployed without .git, so updates were impossible -----
GNOMARCHY_CHECKOUT="$HOME_DIR/.local/share/gnomarchy"
if [[ -d "$GNOMARCHY_CHECKOUT/.git" ]]; then
  ok "Gnomarchy checkout has a git repository (updates possible)"
elif [[ -d "$GNOMARCHY_CHECKOUT" ]]; then
  no "no .git in ~/.local/share/gnomarchy"     "checkout exists but is not a repository; contains: $(ls "$GNOMARCHY_CHECKOUT" | tr '
' ' ')"
else
  no "no Gnomarchy checkout at all" "expected $GNOMARCHY_CHECKOUT"
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

# --- Regression: the dock entry launched nothing and had a broken icon -----
#
# The desktop entry is only useful if its Exec target exists and its Icon
# resolves. Both were wrong: Exec pointed at the raw browser binary rather than
# the Origin wrapper, and a single arbitrary logo size was installed into the
# 128x128 directory, so a 16x16 image was scaled up into a blur.
BRAVE_DESKTOP="$ROOT/usr/share/applications/brave-origin.desktop"
if [[ -f "$BRAVE_DESKTOP" ]]; then
  exec_target="$(awk -F= '/^Exec=/ {print $2; exit}' "$BRAVE_DESKTOP" | awk '{print $1}')"
  if [[ -n "$exec_target" ]]; then
    # Resolve through the image, not the host.
    resolved="$ROOT${exec_target}"
    if [[ -L "$resolved" ]]; then
      link_dest="$(readlink "$resolved")"
      resolved="$ROOT${link_dest}"
    fi
    if [[ -f "$resolved" ]]; then
      ok "Brave desktop entry points at a real binary ($(basename "$exec_target"))"
    else
      no "Brave Exec target does not exist" "$exec_target -> ${resolved#"$ROOT"}"
    fi
  fi

  icon_name="$(awk -F= '/^Icon=/ {print $2; exit}' "$BRAVE_DESKTOP")"
  icon_sizes=0
  for dir in "$ROOT/usr/share/icons/hicolor"/*/apps; do
    [[ -f "$dir/$icon_name.png" ]] && icon_sizes=$((icon_sizes + 1))
  done
  if ((icon_sizes >= 4)); then
    ok "Brave icon installed in $icon_sizes sizes"
  elif ((icon_sizes > 0)); then
    no "Brave icon installed in only $icon_sizes size(s)" "the shell will scale it badly"
  else
    no "Brave icon '$icon_name' is not installed" "the launcher shows a broken icon"
  fi
fi

# --- Regression: extensions shipped without their compiled schemas ---------
#
# GNOME Shell reads an extension's settings from
# <extension>/schemas/gschemas.compiled. Compiling only the system schema
# directory left that file missing, and every extension with settings failed
# to load with GLib.FileError.
uncompiled=()
ext_checked=0
for ext_base in "$ROOT/usr/share/gnome-shell/extensions"   "$HOME_DIR/.local/share/gnome-shell/extensions"; do
  [[ -d "$ext_base" ]] || continue
  for ext_dir in "$ext_base"/*/; do
    [[ -d "$ext_dir/schemas" ]] || continue
    compgen -G "$ext_dir/schemas/*.gschema.xml" >/dev/null 2>&1 || continue
    ext_checked=$((ext_checked + 1))
    [[ -f "$ext_dir/schemas/gschemas.compiled" ]] ||
      uncompiled+=("$(basename "$ext_dir")")
  done
done

if ((ext_checked == 0)); then
  no "no GNOME extensions with schemas found" "extensions were not deployed"
elif ((${#uncompiled[@]} == 0)); then
  ok "all $ext_checked extension schemas are compiled"
else
  no "${#uncompiled[@]} extension(s) have uncompiled schemas" "${uncompiled[*]}"
fi

# --- Regression: a Forge built for the wrong GNOME, or not deployed --------
#
# Dynamic tiling is Forge, bundled from the jcrussell fork. The Forge on
# extensions.gnome.org is the unmaintained upstream and its metadata.json stops
# at GNOME 49: installed on GNOME 50 it sits in enabled-extensions and never
# loads, so `gnomarchy tiling enable` appears to work and tiles nothing.
forge_meta=""
for ext_base in "$ROOT/usr/share/gnome-shell/extensions" "$HOME_DIR/.local/share/gnome-shell/extensions"; do
  candidate="$ext_base/forge@jmmaranan.com/metadata.json"
  [[ -f "$candidate" ]] && forge_meta="$candidate" && break
done

if [[ -z "$forge_meta" ]]; then
  no "Forge is not deployed" "dynamic tiling has no backend to enable"
elif grep -q '"50"' "$forge_meta"; then
  ok "Forge is deployed and declares GNOME 50"
else
  no "the deployed Forge does not declare GNOME 50"     "the shell will refuse to load it; see default/gnome/extensions/PROVENANCE.md"
fi

# --- Regression: dynamic tiling that only ever placed windows --------------
#
# Tiling Shell is the manual mode now. Its enable-autotiling drops a new window
# into a fixed tile of a static layout and never resizes the windows already on
# screen -- which is what the distribution used to ship as "dynamic tiling".
# The installer must leave it off.
TS_OVERRIDE="$ROOT/usr/share/glib-2.0/schemas/org.gnome.shell.extensions.tilingshell.gschema.xml"
if [[ -f "$TS_OVERRIDE" ]]; then
  ok "Tiling Shell's schema is installed system-wide"
else
  no "Tiling Shell's schema is missing from the system schema directory"     "manual tiling cannot be configured"
fi

# --- Regression: Brave binaries extracted without the executable bit -------
#
# zipfile.extractall() drops Unix modes, and only the main binary was chmodded,
# so Brave aborted at startup:
#   FATAL spawn /opt/brave-origin/chrome_crashpad_handler: Permission denied
BRAVE_DIR="$ROOT/opt/brave-origin"
if [[ -d "$BRAVE_DIR" ]]; then
  non_exec=()
  for helper in brave chrome_crashpad_handler chrome-sandbox; do
    bin="$BRAVE_DIR/$helper"
    [[ -f "$bin" ]] || continue
    [[ -x "$bin" ]] || non_exec+=("$helper")
  done
  if ((${#non_exec[@]} == 0)); then
    ok "Brave binaries carry the executable bit"
  else
    no "${#non_exec[@]} Brave binary/binaries not executable" "${non_exec[*]}"
  fi

  if [[ -f "$BRAVE_DIR/chrome-sandbox" ]]; then
    perms="$(stat -c '%a' "$BRAVE_DIR/chrome-sandbox" 2>/dev/null)"
    [[ "$perms" == "4755" ]] &&
      ok "chrome-sandbox is setuid root" ||
      no "chrome-sandbox has mode $perms" "expected 4755"
  fi
else
  no "Brave Origin not installed" "expected $BRAVE_DIR"
fi

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
