#!/bin/bash

# Host side of the screenshot capture: boot the installed image and photograph
# its video output while the in-guest script composes the desktop.
#
# The guest cannot photograph itself - GNOME Shell refuses its screenshot
# interface to any sender outside the allowlist it ships with - so the pictures
# are taken here, through the QEMU monitor. See iso/tests/capture-screenshots.sh
# for the guest half and the full reasoning.
#
# One invocation is one boot. The guest powers itself off when its phase is
# done, so this returns when the picture taking is over rather than on a timer;
# the timeout is only a backstop against a session that never comes up.
#
# Usage:
#   capture-host.sh DISK OVMF_CODE OVMF_VARS OUTDIR LABEL
#
# Environment:
#   ACCEL         qemu acceleration arguments (default: -accel tcg)
#   MEM           guest memory in MB (default: 4096)
#   INTERVAL      seconds between frames (default: 5)
#   BOOT_TIMEOUT  hard limit on the boot, in seconds (default: 1500)

set -eEo pipefail

if (( $# != 5 )); then
  echo "Usage: capture-host.sh DISK OVMF_CODE OVMF_VARS OUTDIR LABEL" >&2
  exit 2
fi

DISK="$1"
OVMF_CODE="$2"
OVMF_VARS="$3"
OUTDIR="$(mkdir -p "$4" && cd "$4" && pwd)"
LABEL="$5"

ACCEL="${ACCEL:--accel tcg}"
MEM="${MEM:-4096}"
INTERVAL="${INTERVAL:-5}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-1500}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOCK="$PWD/qmp-$LABEL.sock"
SERIAL="$PWD/capture-$LABEL-serial.log"

rm -f "$SOCK"

echo "--- capture boot: $LABEL ---"
echo "disk:     $DISK"
echo "frames:   $OUTDIR"
echo "interval: ${INTERVAL}s, timeout: ${BOOT_TIMEOUT}s"

# virtio-vga carrying an explicit EDID resolution, so the frames come out at
# 1080p rather than the 1024x768 a bare VGA device negotiates. The default
# display device has to be off or the guest sees two of them.
qemu_args=(
  $ACCEL
  -smp 4
  -m "$MEM"
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
  -drive "if=pflash,format=raw,file=$OVMF_VARS"
  -drive "file=$DISK,if=virtio,format=qcow2"
  -netdev user,id=n0
  -device virtio-net-pci,netdev=n0
  -vga none
  -device virtio-vga,xres=1920,yres=1080
  -display none
  -serial "file:$SERIAL"
  -qmp "unix:$SOCK,server,nowait"
  -no-reboot
)

set +e
sudo timeout "$BOOT_TIMEOUT" qemu-system-x86_64 "${qemu_args[@]}" &
qemu_pid=$!

# QEMU owns the socket as root, so the photographer has to be root too.
sudo python3 "$HERE/screendump-loop.py" "$SOCK" "$OUTDIR" "$LABEL" "$INTERVAL" "$BOOT_TIMEOUT" &
loop_pid=$!

wait "$qemu_pid"
qemu_status=$?
echo "qemu exit: $qemu_status"

# The loop notices the dead monitor on its own, but not instantly.
wait "$loop_pid" 2>/dev/null
set -e

sudo chown -R "$(id -un):$(id -gn)" "$OUTDIR" "$SERIAL" 2>/dev/null || true
sudo rm -f "$SOCK"

frames="$(ls -1 "$OUTDIR"/$LABEL-*.ppm 2>/dev/null | wc -l)"
echo "$LABEL: $frames raw frames"

# A boot that produced nothing is worth reporting here rather than leaving the
# caller to infer it from an empty directory.
if (( frames == 0 )); then
  echo "WARNING: no frames from $LABEL - the last of the serial log follows"
  tail -40 "$SERIAL" 2>/dev/null || echo "(no serial output)"
fi
