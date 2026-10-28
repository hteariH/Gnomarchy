#!/bin/bash
# Paths and helpers shared by gnomarchy-boot and its libraries.
#
# Every path is rooted at GNOMARCHY_BOOT_ROOT, empty on a real system, so the
# fast tests run this exact code against a throwaway tree.

BOOT_ROOT="${GNOMARCHY_BOOT_ROOT:-}"
BOOT_ESP="$BOOT_ROOT/boot"
BOOT_STATE="$BOOT_ESP/gnomarchy"
BOOT_STORE="$BOOT_STATE/store"
BOOT_ENTRIES="$BOOT_STATE/entries"
BOOT_CONF="$BOOT_ROOT/etc/gnomarchy/boot.conf"
BOOT_THEME="$BOOT_ROOT/etc/gnomarchy/boot-theme.conf"
BOOT_CMDLINE="$BOOT_ROOT/etc/kernel/cmdline"
BOOT_SNAPSHOTS="$BOOT_ROOT/.snapshots"
BOOT_LIMINE_SHARE="$BOOT_ROOT/usr/share/limine"

boot_log() { printf 'gnomarchy-boot: %s\n' "$*" >&2; }

boot_die() {
  boot_log "error: $*"
  exit 1
}

# boot_read_kv FILE ARRAY — loads KEY=VALUE lines into an associative array.
# Never sources the file: snapshot descriptions and the theme file hold text a
# user chose.
boot_read_kv() {
  local file="$1" line
  local -n _boot_kv="$2"
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
      _boot_kv["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  done <"$file"
  return 0
}

boot_hash() {
  local sum
  sum="$(b2sum "$1")" || return 1
  printf '%s\n' "${sum%% *}"
}

# The running root's filesystem type and subvolume, as findmnt reports them.
# GNOMARCHY_BOOT_ROOT_FSTYPE and GNOMARCHY_BOOT_ROOT_FSROOT exist for the
# tests, whose root is the container's.
boot_root_fstype() {
  if [[ -n "${GNOMARCHY_BOOT_ROOT_FSTYPE:-}" ]]; then
    printf '%s\n' "$GNOMARCHY_BOOT_ROOT_FSTYPE"
  else
    findmnt -no FSTYPE /
  fi
}

boot_root_fsroot() {
  if [[ -n "${GNOMARCHY_BOOT_ROOT_FSROOT:-}" ]]; then
    printf '%s\n' "$GNOMARCHY_BOOT_ROOT_FSROOT"
  else
    findmnt -no FSROOT /
  fi
}
