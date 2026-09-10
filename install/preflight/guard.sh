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

# Test sudo access
if ! sudo -v; then
  gnomarchy_error "Sudo privileges are required to install Gnomarchy."
  exit 1
fi
