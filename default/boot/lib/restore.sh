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

# boot_restore_stage HASH TMP — copies store file HASH to TMP and checks it.
boot_restore_stage() {
  local got
  cp "$BOOT_STORE/$1" "$2" || return 1
  got="$(boot_hash "$2")" && [[ "$got" == "$1" ]]
}

# boot_restore_unstage — removes the ESP files a restore staged but did not use.
boot_restore_unstage() {
  rm -f "$BOOT_ESP/restore.vmlinuz.tmp" "$BOOT_ESP/restore.initramfs.tmp"
}

boot_restore() {
  local n="$1" kernel source top backup stamp h fstype fsroot new
  local -A e=()
  local record=0
  [[ "$n" =~ ^[1-9][0-9]*$ ]] || boot_die "restore needs a snapshot number, got '$n'"
  [[ -d "$BOOT_SNAPSHOTS/$n/snapshot" ]] || boot_die "no snapshot $n in $BOOT_SNAPSHOTS"

  # A restore already happened and nothing rebooted: the running root is the
  # old @, parked as @restore-backup-*. Restoring again would park that one and
  # could leave no root to come back to. An overlay root (booted from a
  # snapshot) is not btrfs, so this does not apply there.
  fstype="$(boot_root_fstype)" || boot_die "cannot read the type of the running root"
  fsroot="$(boot_root_fsroot)" || boot_die "cannot read the subvolume of the running root"
  if [[ "$fstype" == btrfs && "$fsroot" == /@restore-backup-* ]]; then
    boot_die "a restore is already pending; reboot before restoring again"
  fi

  if boot_read_kv "$BOOT_ENTRIES/$n.conf" e; then
    record=1
    [[ -n "${e[KERNEL]:-}" ]] || boot_die "snapshot $n's menu record has no KERNEL"
    for h in "${e[KERNEL_HASH]:-}" "${e[INITRAMFS_HASH]:-}"; do
      [[ -n "$h" && -f "$BOOT_STORE/$h" ]] || boot_die "snapshot $n's boot files are missing from $BOOT_STORE"
    done
    # Staged before anything changes, so a full ESP stops the restore here.
    if ! boot_restore_stage "${e[KERNEL_HASH]}" "$BOOT_ESP/restore.vmlinuz.tmp" ||
      ! boot_restore_stage "${e[INITRAMFS_HASH]}" "$BOOT_ESP/restore.initramfs.tmp"; then
      boot_restore_unstage
      boot_die "could not stage snapshot $n's kernel on the ESP; nothing was changed"
    fi
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

  # @ is never missing for longer than a rename: the new root is made beside
  # it first, then the two names are swapped, and a failed swap is undone.
  stamp="$(date +%Y%m%d-%H%M%S)"
  new="$top/@restore-new-$stamp"
  if ! btrfs subvolume snapshot "$top/@snapshots/$n/snapshot" "$new"; then
    if [[ -d "$new" ]]; then
      btrfs subvolume delete "$new"
    fi
    boot_restore_unstage
    boot_die "could not make snapshot $n into a new root; @ is unchanged"
  fi
  if ! mv "$top/@" "$top/@restore-backup-$stamp"; then
    btrfs subvolume delete "$new"
    boot_restore_unstage
    boot_die "could not move @ aside; @ is unchanged"
  fi
  if ! mv "$new" "$top/@"; then
    if mv "$top/@restore-backup-$stamp" "$top/@"; then
      btrfs subvolume delete "$new"
      boot_restore_unstage
      boot_die "could not put the new root in place; @ is unchanged"
    fi
    boot_restore_unstage
    boot_die "could not put the new root in place and could not move the old one back; move $top/@restore-backup-$stamp to @ by hand"
  fi
  boot_log "snapshot $n is now @; the previous root is kept as @restore-backup-$stamp"

  if ((record)); then
    mv -f "$BOOT_ESP/restore.vmlinuz.tmp" "$BOOT_ESP/vmlinuz-${e[KERNEL]}"
    mv -f "$BOOT_ESP/restore.initramfs.tmp" "$BOOT_ESP/initramfs-${e[KERNEL]}.img"
  fi
  boot_write_conf
}
