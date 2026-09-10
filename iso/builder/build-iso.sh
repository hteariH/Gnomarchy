#!/usr/bin/env bash

# Build Gnomarchy Bootable Installation ISO
set -e

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
ISO_DIR="$REPO_ROOT/iso"
CONFIGS_DIR="$ISO_DIR/configs"
OUT_DIR="${1:-$REPO_ROOT/out}"
WORK_DIR="/tmp/gnomarchy-iso-work"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (or with sudo) to invoke mkarchiso."
  exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "archiso package not found. Installing..."
  pacman -S --noconfirm --needed archiso git
fi

echo -e "\033[1;36m==> Building Gnomarchy Linux ISO\033[0m"
echo "Repository Root: $REPO_ROOT"
echo "Output Directory: $OUT_DIR"

mkdir -p "$OUT_DIR"
mkdir -p "$CONFIGS_DIR/airootfs/root/gnomarchy"

# Synchronize current repository files into the ISO rootfs for offline installation
echo "Syncing Gnomarchy files into live filesystem..."
rsync -a --exclude=".git" --exclude="out" --exclude="iso/work" "$REPO_ROOT/" "$CONFIGS_DIR/airootfs/root/gnomarchy/"

# Cleanup previous working cache
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

# Run mkarchiso
echo "Running mkarchiso..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$CONFIGS_DIR"

echo -e "\n\033[1;32m✓ ISO Build Completed Successfully!\033[0m"
ls -lh "$OUT_DIR"/*.iso
