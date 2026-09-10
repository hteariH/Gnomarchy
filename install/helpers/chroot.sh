#!/bin/bash

# Detect if we are inside a chroot environment (e.g. during archinstall or ISO setup)
is_chroot() {
  if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/ 2>/dev/null)" ]; then
    return 0
  fi
  return 1
}

# Run command as the non-root target user
run_as_user() {
  if [[ $EUID -eq 0 && -n "$SUDO_USER" ]]; then
    sudo -u "$SUDO_USER" "$@"
  else
    "$@"
  fi
}
