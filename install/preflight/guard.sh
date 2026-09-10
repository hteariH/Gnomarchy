#!/bin/bash

# Guard: Ensure we are running on Arch Linux
if [ ! -f /etc/arch-release ]; then
  gnomarchy_error "Gnomarchy requires an Arch Linux base system (/etc/arch-release not found)."
  exit 1
fi

# Ensure user is not root directly, but has sudo capabilities
if [[ $EUID -eq 0 && -z "$GNOMARCHY_CHROOT_INSTALL" ]]; then
  gnomarchy_error "Do not run the Gnomarchy installer directly as root. Run as a regular user with sudo privileges."
  exit 1
fi

# Verify sudo access.
#
# A bare `sudo -v` prints a lone "[sudo] password for ..." line in the middle of
# a long install log. It is easy to miss, and when it times out the entire
# installation aborts after the base system is already on disk. Check
# non-interactively first, and if a password really is needed, say so loudly
# before blocking.
if ! sudo -n true 2>/dev/null; then
  echo
  gnomarchy_warn "================================================================"
  gnomarchy_warn "  Your sudo password is required to continue."
  gnomarchy_warn "  Type it at the prompt below - the installer is waiting."
  gnomarchy_warn "================================================================"
  echo

  if ! sudo -v; then
    echo
    gnomarchy_error "Sudo privileges are required to install Gnomarchy."
    gnomarchy_error "Nothing has been changed on this system yet; re-run the installer to try again."
    exit 1
  fi
fi

# Keep the sudo timestamp alive for the length of the install so long package
# stages cannot expire it and trigger another unattended prompt.
(
  while true; do
    sudo -n true 2>/dev/null || exit
    sleep 50
  done
) &
GNOMARCHY_SUDO_KEEPALIVE_PID=$!
export GNOMARCHY_SUDO_KEEPALIVE_PID

# Stop the keepalive when the installer exits, however it exits.
trap 'kill "$GNOMARCHY_SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
