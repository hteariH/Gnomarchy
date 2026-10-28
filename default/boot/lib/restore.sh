#!/bin/bash
# Make snapshot N the root filesystem from the next boot on. The same steps
# work whether the running system is @ or snapshot N itself.

# boot_delete_subvolume TOP RELPATH — a subvolume and every subvolume nested in
# it (systemd creates var/lib/machines and var/lib/portables as subvolumes, and
# a subvolume that holds others cannot be deleted).
boot_delete_subvolume() {
  local top="$1" rel="$2" child
  while IFS= read -r child; do
    [[ -n "$child" ]] && boot_delete_subvolume "$top" "$child"
  done < <(btrfs subvolume list -o "$top/$rel" | sed -n 's/^.* path //p')
  btrfs subvolume delete "$top/$rel"
}

boot_restore() {
  local n="$1" kernel source top backup stamp h
  local -A e=()
  [[ "$n" =~ ^[1-9][0-9]*$ ]] || boot_die "restore needs a snapshot number, got '$n'"
  [[ -d "$BOOT_SNAPSHOTS/$n/snapshot" ]] || boot_die "no snapshot $n in $BOOT_SNAPSHOTS"

  if boot_read_kv "$BOOT_ENTRIES/$n.conf" e; then
    for h in "${e[KERNEL_HASH]:-}" "${e[INITRAMFS_HASH]:-}"; do
      [[ -n "$h" && -f "$BOOT_STORE/$h" ]] || boot_die "snapshot $n's boot files are missing from $BOOT_STORE"
    done
  else
    # No menu record (the ESP budget dropped it): the restored root can only
    # boot the kernel already on the ESP, so the snapshot must hold its modules.
    kernel="$(boot_default_kernel)" || exit 1
    boot_snapshot_kernel_version "$n" "$kernel" >/dev/null ||
      boot_die "snapshot $n has no boot entry and lacks the installed kernel's modules; it would not boot"
  fi

  source="$(findmnt -no SOURCE "$BOOT_ROOT/.snapshots")" || boot_die "/.snapshots is not mounted"
  source="${source%%[*}"
  top="$BOOT_ROOT/run/gnomarchy/btrfs-top"
  mkdir -p "$top"
  mount -o subvolid=5 "$source" "$top"
  # Leave nothing mounted, whatever happens below. Expanded now: $top is
  # local and out of scope by the time the EXIT trap runs.
  # shellcheck disable=SC2064
  trap "umount '$top'" EXIT

  for backup in "$top"/@restore-backup-*; do
    [[ -d "$backup" ]] || continue
    boot_log "deleting the previous backup ${backup##*/}"
    boot_delete_subvolume "$top" "${backup##*/}"
  done

  stamp="$(date +%Y%m%d-%H%M%S)"
  mv "$top/@" "$top/@restore-backup-$stamp"
  btrfs subvolume snapshot "$top/@snapshots/$n/snapshot" "$top/@"
  boot_log "snapshot $n is now @; the previous root is kept as @restore-backup-$stamp"

  if [[ -n "${e[KERNEL]:-}" ]]; then
    install -m644 "$BOOT_STORE/${e[KERNEL_HASH]}" "$BOOT_ESP/vmlinuz-${e[KERNEL]}"
    install -m644 "$BOOT_STORE/${e[INITRAMFS_HASH]}" "$BOOT_ESP/initramfs-${e[KERNEL]}.img"
  fi
  boot_write_conf
}
