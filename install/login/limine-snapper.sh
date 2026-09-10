#!/bin/bash

gnomarchy_header "Configuring Limine & Snapper Snapshots"

# Check if filesystem is Btrfs
ROOT_FS=$(findmnt -n -o FSTYPE /)
if [[ "$ROOT_FS" == "btrfs" ]]; then
  echo "Btrfs root filesystem detected. Setting up Snapper root config..."
  if ! sudo snapper -c root list >/dev/null 2>&1; then
    sudo snapper -c root create-config / 2>/dev/null || true
  fi

  # Apply optimized snapshot retention limits
  sudo sed -i 's/^NUMBER_LIMIT=".*"/NUMBER_LIMIT="10"/' /etc/snapper/configs/root 2>/dev/null || true
  sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT=".*"/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/root 2>/dev/null || true

  # Enable Snapper automatic cleanup timers
  sudo systemctl enable --now snapper-timeline.timer 2>/dev/null || true
  sudo systemctl enable --now snapper-cleanup.timer 2>/dev/null || true

  # Install Limine Snapper sync hook if limine is installed
  if [ -d /boot/limine ] || [ -f /boot/limine.conf ] || [ -f /boot/EFI/BOOT/limine.conf ]; then
    echo "Limine bootloader detected. Syncing bootloader snapshot hooks..."
    sudo systemctl enable --now snap-pac.timer 2>/dev/null || true
  fi
  gnomarchy_step "Snapper atomic rollback snapshots configured"
else
  gnomarchy_warn "Root filesystem is not Btrfs. Skipping Snapper rollback configuration."
fi
