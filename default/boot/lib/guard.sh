#!/bin/bash
# Refuses package transactions on a root that is about to be thrown away.
#
# Booted from a snapshot, the root is a tmpfs overlay; after a restore and
# before the reboot, it is the old @, parked as @restore-backup-*. Either way
# the ESP is the persistent one: a kernel upgrade would put a new vmlinuz and
# initramfs there and point the menu at them, while the matching modules
# vanish with the root, and the next normal boot would run a kernel without
# its modules. Read-only: takes no lock, so it can run beside any writer.

# The snapshot named by gnomarchy.snapshot= on the running command line.
boot_booted_snapshot() {
  local word
  local -a words
  read -ra words <"$BOOT_ROOT/proc/cmdline" || return 1
  for word in "${words[@]}"; do
    if [[ "$word" == gnomarchy.snapshot=* ]]; then
      printf '%s\n' "${word#gnomarchy.snapshot=}"
      return 0
    fi
  done
  return 1
}

# boot_discarded_root — prints why the running root will be thrown away and
# succeeds, or fails silently when it will not. An unreadable /proc/cmdline or
# root mount counts as "not discarded": a bare chroot without /proc is a
# rescue, where refusing pacman would do more harm than the check prevents.
boot_discarded_root() {
  local n fstype fsroot
  if [[ -r "$BOOT_ROOT/proc/cmdline" ]] && n="$(boot_booted_snapshot)"; then
    printf 'this system is running snapshot %s; changes here are lost at reboot - restore it first with gnomarchy snapshot restore %s\n' "$n" "$n"
    return 0
  fi
  if fstype="$(boot_root_fstype)" && fsroot="$(boot_root_fsroot)" &&
    [[ "$fstype" == btrfs && "$fsroot" == /@restore-backup-* ]]; then
    printf 'a restore is pending; reboot first\n'
    return 0
  fi
  return 1
}

boot_guard() {
  local reason
  if [[ ! -r "$BOOT_ROOT/proc/cmdline" ]]; then
    boot_log "warning: cannot read $BOOT_ROOT/proc/cmdline; not checking for a snapshot boot"
  fi
  if reason="$(boot_discarded_root)"; then
    boot_log "$reason"
    return 1
  fi
  return 0
}
