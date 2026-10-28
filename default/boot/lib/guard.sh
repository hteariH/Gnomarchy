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

boot_guard() {
  local n fstype fsroot
  if [[ ! -r "$BOOT_ROOT/proc/cmdline" ]]; then
    # Never the case on a booted system. A bare chroot without /proc is a
    # rescue, where refusing pacman would do more harm than the check prevents.
    boot_log "warning: cannot read $BOOT_ROOT/proc/cmdline; not checking for a snapshot boot"
  elif n="$(boot_booted_snapshot)"; then
    boot_log "this system is running snapshot $n; changes here are lost at reboot - restore it first with gnomarchy snapshot restore $n"
    return 1
  fi
  # The same reasoning: a chroot onto a directory that is no mount point gives
  # findmnt no root to read, and that must not block package management.
  if ! fstype="$(boot_root_fstype)" || ! fsroot="$(boot_root_fsroot)"; then
    boot_log "warning: cannot read the running root's mount; not checking for a pending restore"
    return 0
  fi
  if [[ "$fstype" == btrfs && "$fsroot" == /@restore-backup-* ]]; then
    boot_log "a restore is pending; reboot first"
    return 1
  fi
  return 0
}
