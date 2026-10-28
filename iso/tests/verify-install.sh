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

# --- Regression: a package list nothing read --------------------------------
# These sat in gnomarchy-other.packages, which no stage ever installed.
for pkg in chromium obs-studio libreoffice-fresh obsidian spotify-launcher mise; do
  if compgen -G "$ROOT/var/lib/pacman/local/$pkg-[0-9]*" >/dev/null; then
    ok "$pkg is installed"
  else
    no "$pkg is not installed"
  fi
done
# Claude Code's native installer links ~/.local/bin/claude to its versions
# directory; the link is absolute, so test it with -L (see CLAUDE.md).
if [[ -L "$HOME_DIR/.local/bin/claude" || -x "$HOME_DIR/.local/bin/claude" ]]; then
  ok "Claude Code is installed"
else
  no "Claude Code is not installed" "expected $HOME_DIR/.local/bin/claude"
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

# --- Regression: extensions built for an older GNOME ----------------------
#
# The shell refuses to load an extension whose metadata.json does not list its
# major version, and says nothing about it: the extension sits in
# enabled-extensions and does nothing. The bundled zips are pinned while Arch
# rolls, so a GNOME release that lands between two Gnomarchy releases leaves
# them behind -- GNOME 51 did that to seven of nine. The version comes from the
# installed package, not from a constant, so the next GNOME trips this too.
#
# Arch gives gnome-shell an epoch, so the database entry is gnome-shell-1:51.1-1;
# reading the first number off it took the epoch for the version.
shell_pkg="$(compgen -G "$ROOT/var/lib/pacman/local/gnome-shell-[0-9]*" | head -1)"
shell_major="$(basename "${shell_pkg:-}" | sed -nE 's/^gnome-shell-([0-9]+:)?([0-9]+).*/\2/p')"
stale=()
meta_checked=0
for meta in "$HOME_DIR/.local/share/gnome-shell/extensions"/*/metadata.json; do
  [[ -f "$meta" ]] || continue
  meta_checked=$((meta_checked + 1))
  grep -q "\"$shell_major\"" "$meta" || stale+=("$(basename "$(dirname "$meta")")")
done

if [[ -z "$shell_major" ]]; then
  no "cannot tell which GNOME is installed" "no gnome-shell entry in $ROOT/var/lib/pacman/local"
elif ((meta_checked == 0)); then
  no "no Gnomarchy extensions deployed" "expected them under ~/.local/share/gnome-shell/extensions"
elif ((${#stale[@]} == 0)); then
  ok "all $meta_checked deployed extensions declare GNOME $shell_major"
else
  no "${#stale[@]} extension(s) do not declare GNOME $shell_major" "${stale[*]} -- the shell will not load them; see default/gnome/extensions/PROVENANCE.md"
fi

# --- Regression: tiling that cannot be configured -------------------------
#
# Tiling Shell is Gnomarchy's tiling, configured by first-run with its
# auto-tiling off: that drops a new window into a fixed tile of a static layout
# and never resizes the windows already on screen. None of that configuration
# can be written without the schema.
TS_OVERRIDE="$ROOT/usr/share/glib-2.0/schemas/org.gnome.shell.extensions.tilingshell.gschema.xml"
if [[ -f "$TS_OVERRIDE" ]]; then
  ok "Tiling Shell's schema is installed system-wide"
else
  no "Tiling Shell's schema is missing from the system schema directory"     "tiling cannot be configured"
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

# --- Removed: Alacritty and the screensaver ---------------------------------
# GNOME Terminal is the terminal; a second one only cost a package and a theme
# step. The themes' alacritty.toml files stay: they are the palette format.
if compgen -G "$ROOT/var/lib/pacman/local/alacritty-[0-9]*" >/dev/null; then
  no "alacritty is installed" "it was dropped from gnomarchy-base.packages"
else
  ok "alacritty is not installed"
fi
if [[ -e "$ROOT/usr/local/bin/gnomarchy-screensaver" || -L "$ROOT/usr/local/bin/gnomarchy-screensaver" ]]; then
  no "gnomarchy-screensaver is still published" "the screensaver was removed"
else
  ok "no gnomarchy-screensaver command"
fi

# --- Windows apps: WinBoat, opt-in -----------------------------------------
# The QEMU Windows VM is gone, and with it the packages only it used.
for pkg in qemu-desktop edk2-ovmf swtpm; do
  if compgen -G "$ROOT/var/lib/pacman/local/$pkg-[0-9]*" >/dev/null; then
    no "$pkg is installed" "only the removed Windows VM used it"
  else
    ok "$pkg is not installed"
  fi
done
WINDOWS_CMD="$HOME_DIR/.local/share/gnomarchy/bin/gnomarchy-windows"
if [[ -L "$ROOT/usr/local/bin/gnomarchy-windows" ]] && grep -q 'winboat-bin' "$WINDOWS_CMD"; then
  ok "gnomarchy windows is the WinBoat installer"
else
  no "gnomarchy windows is not the WinBoat installer" "$WINDOWS_CMD"
fi

# --- Tool configs the theme engine writes into -----------------------------

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

# --- The control center ----------------------------------------------------
for pkg in gjs gtk4 libadwaita; do
  if [[ -d "$ROOT/var/lib/pacman/local" ]] &&
    compgen -G "$ROOT/var/lib/pacman/local/$pkg-[0-9]*" >/dev/null; then
    ok "$pkg is installed"
  else
    no "$pkg is not installed" "the control center cannot start without it"
  fi
done

GUI_ENTRY="$HOME_DIR/.local/share/gnomarchy/gui/src/main.js"
if [[ -f "$GUI_ENTRY" ]]; then
  ok "control center source is present"
else
  no "no control center at $GUI_ENTRY"
fi

DESKTOP_ENTRY="$HOME_DIR/.local/share/applications/org.gnomarchy.ControlCenter.desktop"
if [[ -f "$DESKTOP_ENTRY" ]]; then
  ok "control center desktop entry is published"
else
  no "no desktop entry at $DESKTOP_ENTRY" "install/config/control-center.sh did not run"
fi

# A half-applied port -- GUI files present but the commands still spawning a
# terminal -- would otherwise pass every check above.
terminal_relics=0
for cmd in gnomarchy-menu gnomarchy-manual gnomarchy-keybindings; do
  script="$HOME_DIR/.local/share/gnomarchy/bin/$cmd"
  [[ -f "$script" ]] || continue
  if grep -q 'exec gnome-terminal\|exec alacritty' "$script"; then
    terminal_relics=$((terminal_relics + 1))
    no "$cmd still re-execs into a terminal"
  fi
done
(( terminal_relics == 0 )) && ok "the three commands no longer spawn a terminal"

# --- Boot: Limine, initramfs and snapshots ---------------------------------
# README promised snapshots in the Limine menu while nothing wrote them; the
# snapper config was never created; LUKS installs got a busybox hook in a
# systemd initramfs; plymouth was never added. Each check below is one of those.
BOOT_DIR="$ROOT/boot"
LIMINE_CONF="$BOOT_DIR/limine.conf"
CMDLINE_FILE="$ROOT/etc/kernel/cmdline"
b2() { b2sum "$1" | cut -d' ' -f1; }

cmdline=""
if [[ -f "$CMDLINE_FILE" ]]; then
  cmdline="$(<"$CMDLINE_FILE")"
  ok "/etc/kernel/cmdline exists"
else
  no "no /etc/kernel/cmdline" "gnomarchy-boot has nothing to build the menu from"
fi

if [[ -f "$LIMINE_CONF" ]]; then
  refs=0
  bad=0
  while read -r path hash; do
    refs=$((refs + 1))
    if [[ ! -f "$BOOT_DIR$path" ]]; then
      no "limine.conf points at a missing file" "$path"
      bad=$((bad + 1))
    elif [[ "$(b2 "$BOOT_DIR$path")" != "$hash" ]]; then
      no "limine.conf hash does not match" "$path"
      bad=$((bad + 1))
    fi
  done < <(sed -nE 's/^[[:space:]]*(kernel_path|module_path): boot\(\):([^#]+)#([0-9a-f]{128})$/\2 \3/p' "$LIMINE_CONF")
  unhashed="$(grep -cE '^[[:space:]]*(kernel_path|module_path): boot\(\):[^#]*$' "$LIMINE_CONF")"
  if ((refs > 0 && bad == 0 && unhashed == 0)); then
    ok "limine.conf: all $refs boot files exist and match their blake2b hashes"
  elif ((refs == 0)); then
    no "limine.conf has no hashed kernel or initramfs paths"
  elif ((unhashed > 0)); then
    no "limine.conf has $unhashed boot paths without a hash"
  fi
  grep -qx 'default_entry: Gnomarchy/linux' "$LIMINE_CONF" &&
    ok "the menu defaults to Gnomarchy/linux" || no "the menu does not default to Gnomarchy/linux"
  grep -qx 'interface_branding: Gnomarchy' "$LIMINE_CONF" && grep -q '^term_palette: ' "$LIMINE_CONF" &&
    ok "the menu carries the theme palette" || no "no theme palette in limine.conf"
  [[ -n "$cmdline" ]] && grep -qxF "    kernel_cmdline: $cmdline" "$LIMINE_CONF" &&
    ok "the kernel entry boots /etc/kernel/cmdline" || no "no entry boots /etc/kernel/cmdline"
  fs_uuid="$(findmnt -no UUID --target "$ROOT")"
  [[ -n "$fs_uuid" && " $cmdline " == *" root=UUID=$fs_uuid "* ]] &&
    ok "root=UUID matches the installed Btrfs" || no "root=UUID does not match the Btrfs UUID" "fs: $fs_uuid, cmdline: $cmdline"
else
  no "no limine.conf on the ESP"
fi

for efi in EFI/BOOT/BOOTX64.EFI EFI/limine/BOOTX64.EFI; do
  if [[ -f "$BOOT_DIR/$efi" && "$(b2 "$BOOT_DIR/$efi")" == "$(b2 "$ROOT/usr/share/limine/BOOTX64.EFI")" ]]; then
    ok "$efi is the installed Limine"
  else
    no "$efi is missing or not the installed Limine"
  fi
done
if [[ -f "$BOOT_DIR/limine-bios.sys" && "$(b2 "$BOOT_DIR/limine-bios.sys")" == "$(b2 "$ROOT/usr/share/limine/limine-bios.sys")" ]]; then
  ok "limine-bios.sys is on the ESP"
else
  no "limine-bios.sys missing from the ESP"
fi
if [[ -n "${GNOMARCHY_TEST_DISK:-}" ]]; then
  # The CI disk is a fresh qcow2, so the boot code area is zeroed (wipefs only
  # erases signatures); only limine bios-install writes it.
  if (($(head -c 440 "$GNOMARCHY_TEST_DISK" | tr -d '\0' | wc -c) > 0)); then
    ok "the MBR carries boot code (limine bios-install ran)"
  else
    no "the MBR boot code is empty" "limine bios-install never ran on $GNOMARCHY_TEST_DISK"
  fi
fi
esp_dev="$(findmnt -no SOURCE --target "$BOOT_DIR")"
if [[ -n "$esp_dev" ]] && (($(blockdev --getsize64 "$esp_dev") >= 4 * 1024 * 1024 * 1024)); then
  ok "the ESP is at least 4 GiB"
else
  no "the ESP is smaller than 4 GiB" "$esp_dev"
fi

DROPIN="$ROOT/etc/mkinitcpio.conf.d/gnomarchy.conf"
if [[ -f "$DROPIN" ]]; then
  hooks=" $(sed -n 's/^HOOKS=(\(.*\))$/\1/p' "$DROPIN") "
  missing=()
  for h in systemd plymouth sd-vconsole gnomarchy-overlay; do
    [[ "$hooks" == *" $h "* ]] || missing+=("$h")
  done
  ((${#missing[@]} == 0)) && ok "initramfs HOOKS include systemd, plymouth, sd-vconsole, gnomarchy-overlay" ||
    no "initramfs HOOKS lack: ${missing[*]}" "$hooks"
  [[ "$hooks" == *" udev "* || "$hooks" == *" encrypt "* ]] &&
    no "busybox hooks in a systemd initramfs" "$hooks"
  if [[ "${GNOMARCHY_TEST_ENCRYPT:-n}" == y ]]; then
    [[ "$hooks" == *" sd-encrypt "* ]] && ok "sd-encrypt is in HOOKS" || no "an encrypted install without sd-encrypt"
  else
    [[ "$hooks" == *" sd-encrypt "* ]] &&
      no "sd-encrypt in HOOKS on a plain install" "$hooks" || ok "no sd-encrypt in HOOKS on a plain install"
  fi
else
  no "no /etc/mkinitcpio.conf.d/gnomarchy.conf"
fi
[[ -f "$ROOT/etc/initcpio/install/gnomarchy-overlay" ]] &&
  ok "the gnomarchy-overlay initcpio hook is installed" || no "no gnomarchy-overlay initcpio hook"
grep -q 'subvolid=' "$ROOT/etc/fstab" &&
  no "fstab pins subvolid=" "snapshots and a restored @ cannot mount" || ok "fstab mounts by subvolume name only"

SNAPCFG="$ROOT/etc/snapper/configs/root"
if [[ -f "$SNAPCFG" ]]; then
  for kv in 'TIMELINE_CREATE="no"' 'NUMBER_LIMIT="10"' 'ALLOW_GROUPS="wheel"'; do
    grep -qxF "$kv" "$SNAPCFG" && ok "snapper root config: $kv" || no "snapper root config lacks $kv"
  done
else
  no "no snapper root config" "snapper-init never ran"
fi
grep -qE '^SNAPPER_CONFIGS="(.* )?root( .*)?"$' "$ROOT/etc/conf.d/snapper" &&
  ok "SNAPPER_CONFIGS lists root" || no "SNAPPER_CONFIGS does not list root"
[[ -L "$ROOT/etc/systemd/system/timers.target.wants/snapper-cleanup.timer" ]] &&
  ok "snapper-cleanup.timer is enabled" || no "snapper-cleanup.timer is not enabled"
[[ -L "$ROOT/etc/systemd/system/timers.target.wants/snapper-timeline.timer" ]] &&
  no "snapper-timeline.timer is enabled" "timeline snapshots are off by design"
[[ -L "$ROOT/etc/systemd/system/paths.target.wants/gnomarchy-boot-theme.path" ]] &&
  ok "the boot-theme path unit is enabled" || no "gnomarchy-boot-theme.path is not enabled"
[[ -x "$ROOT/usr/lib/snapper/plugins/50-gnomarchy-boot" ]] &&
  ok "the snapper plugin is installed" || no "no executable snapper plugin"
for hook in 00-gnomarchy-guard.hook 95-gnomarchy-boot.hook 95-gnomarchy-limine.hook; do
  [[ -f "$ROOT/etc/pacman.d/hooks/$hook" ]] && ok "pacman hook $hook" || no "no pacman hook $hook"
done
# A hand-run mkinitcpio -P left the menu naming the old image's hash.
[[ -x "$ROOT/etc/initcpio/post/gnomarchy-boot" ]] &&
  ok "the mkinitcpio post hook is installed" || no "no executable mkinitcpio post hook"
compgen -G "$ROOT/var/lib/pacman/local/snap-pac-[0-9]*" >/dev/null &&
  ok "snap-pac is installed" || no "snap-pac is not installed"
if grep -q '<description>Gnomarchy installed</description>' "$ROOT/.snapshots/1/info.xml" 2>/dev/null; then
  ok "snapshot 1 \"Gnomarchy installed\" exists"
else
  # The test reads .snapshots through the @snapshots mount; without it this
  # file cannot exist, which the workflow guards against.
  no "no snapshot 1 \"Gnomarchy installed\""
fi
[[ -f "$BOOT_DIR/gnomarchy/entries/1.conf" ]] && grep -q '^///1 | ' "$LIMINE_CONF" &&
  ok "snapshot 1 is in the boot menu" || no "snapshot 1 is not in the boot menu"

# --- The installer's answers ------------------------------------------------
# In CI the answers must arrive; an unset variable would otherwise skip every
# check below without a word (sudo -E dropped them once).
if [[ -n "${CI:-}" && -z "${GNOMARCHY_TEST_HOSTNAME:-}" ]]; then
  no "GNOMARCHY_TEST_* variables did not reach the script" "CI is set but GNOMARCHY_TEST_HOSTNAME is not; the environment was dropped on the way in"
fi
if [[ -n "${GNOMARCHY_TEST_HOSTNAME:-}" ]]; then
  [[ "$(<"$ROOT/etc/hostname")" == "$GNOMARCHY_TEST_HOSTNAME" ]] &&
    ok "hostname is $GNOMARCHY_TEST_HOSTNAME" || no "hostname is not $GNOMARCHY_TEST_HOSTNAME" "$(<"$ROOT/etc/hostname")"
fi
if [[ -n "${GNOMARCHY_TEST_TIMEZONE:-}" ]]; then
  tz_link="$(readlink "$ROOT/etc/localtime")"
  [[ -L "$ROOT/etc/localtime" && "$tz_link" == */zoneinfo/$GNOMARCHY_TEST_TIMEZONE ]] &&
    ok "timezone is $GNOMARCHY_TEST_TIMEZONE" || no "timezone is not $GNOMARCHY_TEST_TIMEZONE" "$tz_link"
fi
if [[ -n "${GNOMARCHY_TEST_KEYMAP:-}" ]]; then
  # shellcheck source=../installer/lib/form.sh
  source "$(dirname "$0")/../installer/lib/form.sh"
  if keymap_load "$GNOMARCHY_TEST_KEYMAP"; then
    grep -qx "KEYMAP=$KB_CONSOLE_KEYMAP" "$ROOT/etc/vconsole.conf" &&
      ok "console keymap is $KB_CONSOLE_KEYMAP" || no "console keymap is not $KB_CONSOLE_KEYMAP"
    grep -qF "Option \"XkbLayout\" \"$KB_XKB_LAYOUT\"" "$ROOT/etc/X11/xorg.conf.d/00-keyboard.conf" &&
      ok "X11 layout is $KB_XKB_LAYOUT" || no "X11 layout is not $KB_XKB_LAYOUT"
    grep -qx "XKB_LAYOUT=$KB_XKB_LAYOUT" "$ROOT/etc/gnomarchy/keyboard.conf" &&
      ok "first-run will set input source $KB_XKB_LAYOUT" || no "keyboard.conf does not name $KB_XKB_LAYOUT"
  else
    no "GNOMARCHY_TEST_KEYMAP $GNOMARCHY_TEST_KEYMAP is not in keymaps.tsv"
  fi
fi
grep -q 'Installation complete' "$ROOT/var/log/gnomarchy-installer.log" &&
  ok "the installer log is on the target" || no "no complete installer log at /var/log/gnomarchy-installer.log"

if [[ "${GNOMARCHY_TEST_ENCRYPT:-n}" != y ]]; then
  [[ "$cmdline" == *"rd.luks.name="* ]] &&
    no "rd.luks.name on a plain install" "$cmdline" || ok "no rd.luks.name on a plain install"
fi
if [[ "${GNOMARCHY_TEST_ENCRYPT:-n}" == y ]]; then
  if [[ -n "${GNOMARCHY_TEST_LUKS_DEV:-}" ]]; then
    luks_uuid="$(blkid -s UUID -o value "$GNOMARCHY_TEST_LUKS_DEV")"
    [[ -n "$luks_uuid" && " $cmdline " == *" rd.luks.name=$luks_uuid=cryptroot "* ]] &&
      ok "rd.luks.name opens the LUKS partition" || no "rd.luks.name does not name $luks_uuid" "$cmdline"
  else
    echo "  SKIP  rd.luks.name check: GNOMARCHY_TEST_LUKS_DEV is not set"
  fi
  if [[ -f "$ROOT/etc/crypttab" ]] && grep -q '^cryptroot' "$ROOT/etc/crypttab"; then
    no "crypttab also opens cryptroot" "the root is opened from the command line"
  else
    ok "crypttab does not compete with rd.luks.name"
  fi
  grep -qx 'AutomaticLoginEnable=true' "$ROOT/etc/gdm/custom.conf" &&
    ok "GDM autologin on the encrypted install" || no "GDM autologin not enabled on the encrypted install"
fi

echo
echo "=== $pass passed, $fail failed ==="
((fail == 0))
