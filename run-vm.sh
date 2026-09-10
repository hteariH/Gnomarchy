#!/usr/bin/env bash

# Test Gnomarchy ISO or Installed Disk in QEMU with UEFI
set -e

ISO_PATH="${1:-out/gnomarchy-linux-*.iso}"
DISK_IMAGE="gnomarchy-test.qcow2"

# Resolve wildcard if needed
ISO_FILE=$(ls -1 $ISO_PATH 2>/dev/null | head -n 1 || true)

if [[ ! -f "$ISO_FILE" && ! -f "$DISK_IMAGE" ]]; then
  echo "Usage: ./run-vm.sh [path/to/gnomarchy.iso]"
  echo "No ISO found matching: $ISO_PATH"
  exit 1
fi

# Locate OVMF UEFI firmware
OVMF_BIOS=""
for ovmf_candidate in \
  "/usr/share/edk2-ovmf/x64/OVMF.fd" \
  "/usr/share/ovmf/x64/OVMF.4m.fd" \
  "/usr/share/OVMF/OVMF_CODE.fd" \
  "/usr/share/edk2/x64/OVMF.4m.fd"; do
  if [[ -f "$ovmf_candidate" ]]; then
    OVMF_BIOS="$ovmf_candidate"
    break
  fi
done

if [[ -z "$OVMF_BIOS" ]]; then
  echo "OVMF firmware not found. Install 'edk2-ovmf' or 'ovmf' package."
  exit 1
fi

# Create test virtual disk if not present
if [[ ! -f "$DISK_IMAGE" ]]; then
  echo "Creating 40GB test virtual drive ($DISK_IMAGE)..."
  qemu-img create -f qcow2 "$DISK_IMAGE" 40G
fi

QEMU_ARGS=(
  -m 8192
  -smp 4
  -cpu host
  -vga virtio
  -display default,show-cursor=on
  -bios "$OVMF_BIOS"
  -drive file="$DISK_IMAGE",if=virtio,format=qcow2
  -net nic,model=virtio -net user
)

if [ -f /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  QEMU_ARGS+=(-enable-kvm)
fi

if [[ -n "$ISO_FILE" && -f "$ISO_FILE" ]]; then
  echo "Booting from ISO: $ISO_FILE"
  QEMU_ARGS+=(-cdrom "$ISO_FILE" -boot d)
else
  echo "Booting from installed virtual disk: $DISK_IMAGE"
fi

exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
