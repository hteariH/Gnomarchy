#!/bin/bash
# Snapshot menu records, the content-addressed store on the ESP, and the ESP
# budget. Called from snapper's plugin, which must finish within seconds and
# must not call snapper, so everything here reads snapper's files directly.

# boot_info_field FILE TAG — one element of snapper's info.xml, entities decoded.
boot_info_field() {
  sed -n "/<$2>/{s:.*<$2>\(.*\)</$2>.*:\1:p;q}" "$1" |
    sed -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e "s/&apos;/'/g" -e 's/&amp;/\&/g'
}

# Printable, one line, at most 60 characters: it becomes a menu title.
boot_clean_text() {
  local s="${1//[^[:print:]]/ }"
  printf '%s' "${s:0:60}"
}

# boot_snapshot_kernel_version N KERNEL — the module version inside snapshot N
# whose vmlinuz is byte for byte the ESP's vmlinuz-KERNEL.
boot_snapshot_kernel_version() {
  local want dir
  want="$(boot_hash "$BOOT_ESP/vmlinuz-$2")" || return 1
  for dir in "$BOOT_SNAPSHOTS/$1/snapshot/usr/lib/modules"/*/; do
    [[ -f "${dir}vmlinuz" ]] || continue
    if [[ "$(boot_hash "${dir}vmlinuz")" == "$want" ]]; then
      dir="${dir%/}"
      printf '%s\n' "${dir##*/}"
      return 0
    fi
  done
  return 1
}

# boot_store_put FILE HASH — copy once; ten snapshots of one kernel share it.
# errexit is off inside this function when a caller tests it, so every step
# that can fail is checked by hand. A full ESP fails the copy; a copy whose
# hash differs from HASH (the source changed while copying) fails the verify.
boot_store_put() {
  local name="${1##*/}" tmp="$BOOT_STORE/$2.tmp" got
  mkdir -p "$BOOT_STORE" || return 1
  [[ -f "$BOOT_STORE/$2" ]] && return 0
  if ! cp "$1" "$tmp"; then
    rm -f "$tmp"
    boot_log "no room on the ESP for $name"
    return 1
  fi
  if ! got="$(boot_hash "$tmp")" || [[ "$got" != "$2" ]]; then
    rm -f "$tmp"
    boot_log "copy of $name did not verify; it changed while it was copied"
    return 1
  fi
  mv -f "$tmp" "$BOOT_STORE/$2" || {
    rm -f "$tmp"
    boot_log "could not place $name in the store"
    return 1
  }
}

boot_snapshot_add() {
  local n="$1" info kernel version kh ih taken desc base
  if [[ ! "$n" =~ ^[1-9][0-9]*$ ]]; then
    boot_log "snapshot number must be a positive integer, got '$n'"
    return 1
  fi
  info="$BOOT_SNAPSHOTS/$n/info.xml"
  if [[ ! -f "$info" || ! -d "$BOOT_SNAPSHOTS/$n/snapshot" ]]; then
    boot_log "snapshot $n not found in $BOOT_SNAPSHOTS"
    return 1
  fi
  base="$(boot_base_cmdline)" || return 1
  boot_snapshot_cmdline "$base" "$n" >/dev/null || return 1
  kernel="$(boot_default_kernel)" || return 1

  # The ESP holds the kernel this snapshot runs: snap-pac's pre snapshot is
  # taken before the transaction, its post snapshot after mkinitcpio's hook.
  if ! version="$(boot_snapshot_kernel_version "$n" "$kernel")"; then
    boot_log "snapshot $n does not contain the ESP's vmlinuz-$kernel; it gets no menu entry"
    return 0
  fi

  # Everything read from info.xml is checked before the store is touched, so a
  # bad snapshot leaves the store as it was.
  taken="$(boot_info_field "$info" date)"
  if [[ -z "$taken" ]] || ! taken="$(date -d "$taken UTC" '+%Y-%m-%d %H:%M')"; then
    boot_log "snapshot $n: no readable date in $info"
    return 1
  fi
  desc="$(boot_clean_text "$(boot_info_field "$info" description)")"

  kh="$(boot_hash "$BOOT_ESP/vmlinuz-$kernel")"
  ih="$(boot_hash "$BOOT_ESP/initramfs-$kernel.img")"

  # Free room before copying: the older entries are the ones to lose.
  boot_enforce_budget
  if ! boot_store_put "$BOOT_ESP/vmlinuz-$kernel" "$kh"; then
    boot_log "snapshot $n gets no menu entry"
    return 1
  fi
  if ! boot_store_put "$BOOT_ESP/initramfs-$kernel.img" "$ih"; then
    boot_log "snapshot $n gets no menu entry"
    return 1
  fi

  mkdir -p "$BOOT_ENTRIES"
  printf 'KERNEL=%s\nVERSION=%s\nKERNEL_HASH=%s\nINITRAMFS_HASH=%s\nDATE=%s\nDESCRIPTION=%s\n' \
    "$kernel" "$version" "$kh" "$ih" "$taken" "$desc" >"$BOOT_ENTRIES/$n.conf.tmp"
  mv -f "$BOOT_ENTRIES/$n.conf.tmp" "$BOOT_ENTRIES/$n.conf"
  boot_log "snapshot $n added to the boot menu (kernel $version)"
  boot_enforce_budget
}

boot_snapshot_remove() {
  if [[ ! "$1" =~ ^[1-9][0-9]*$ ]]; then
    boot_log "snapshot number must be a positive integer, got '$1'"
    return 1
  fi
  rm -f "$BOOT_ENTRIES/$1.conf"
  boot_store_gc
}

# Delete store files no record refers to.
boot_store_gc() {
  local f name
  local -A keep=() e=()
  for f in "$BOOT_ENTRIES"/*.conf; do
    [[ -f "$f" ]] || continue
    e=()
    boot_read_kv "$f" e
    [[ -n "${e[KERNEL_HASH]:-}" ]] && keep["${e[KERNEL_HASH]}"]=1
    [[ -n "${e[INITRAMFS_HASH]:-}" ]] && keep["${e[INITRAMFS_HASH]}"]=1
  done
  for f in "$BOOT_STORE"/*; do
    [[ -f "$f" ]] || continue
    name="${f##*/}"
    if [[ -z "${keep[$name]:-}" ]]; then
      rm -f "$f"
      boot_log "removed ${name:0:12} from the store; no snapshot uses it"
    fi
  done
}

# Percent of the ESP in use. GNOMARCHY_BOOT_ESP_SIZE_KB exists for the tests,
# whose ESP is a plain directory.
boot_esp_usage() {
  local pct="" used
  if [[ -n "${GNOMARCHY_BOOT_ESP_SIZE_KB:-}" ]]; then
    used="$(du -sk --apparent-size "$BOOT_ESP" | cut -f1)" || used=""
    if [[ "$used" =~ ^[0-9]+$ ]] && ((GNOMARCHY_BOOT_ESP_SIZE_KB > 0)); then
      pct=$((used * 100 / GNOMARCHY_BOOT_ESP_SIZE_KB))
    fi
  else
    pct="$(df -P "$BOOT_ESP" | awk 'NR == 2 { sub("%", "", $5); print $5 }')" || pct=""
  fi
  # Unknown usage skips enforcement (0 is under 80) rather than failing the add.
  if [[ ! "$pct" =~ ^[0-9]+$ ]]; then
    boot_log "cannot read ESP usage; skipping the ESP budget"
    pct=0
  fi
  printf '%s\n' "$pct"
}

# Keep the ESP at or under 80%: drop menu entries oldest first. The snapshots
# themselves stay and can still be restored from a running system.
boot_enforce_budget() {
  local -a numbers
  while (($(boot_esp_usage) > 80)); do
    mapfile -t numbers < <(boot_snapshot_numbers)
    if ((${#numbers[@]} <= 1)); then
      boot_log "the ESP is over 80% full with one snapshot entry left; keeping it"
      return 0
    fi
    boot_log "the ESP is over 80% full: dropping the menu entry of snapshot ${numbers[-1]} (the snapshot itself is kept)"
    rm -f "$BOOT_ENTRIES/${numbers[-1]}.conf"
    boot_store_gc
  done
}
