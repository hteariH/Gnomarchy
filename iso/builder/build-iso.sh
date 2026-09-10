#!/usr/bin/env bash

# Build Gnomarchy Bootable Installation ISO
set -e

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
ISO_DIR="$REPO_ROOT/iso"
CONFIGS_DIR="$ISO_DIR/configs"
OUT_DIR="${1:-$REPO_ROOT/out}"
WORK_DIR="/tmp/gnomarchy-iso-work"
PROFILE_DIR="/tmp/gnomarchy-iso-profile"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (or with sudo) to invoke mkarchiso."
  exit 1
fi

# Ensure required packaging tools are present
if ! command -v mkarchiso >/dev/null 2>&1 || ! command -v rsync >/dev/null 2>&1; then
  echo "Installing archiso and dependencies..."
  pacman -Syu --noconfirm archlinux-keyring
  pacman -S --noconfirm --needed archiso git rsync base-devel
fi

echo -e "\033[1;36m==> Preparing Gnomarchy ISO Profile\033[0m"
echo "Repository Root: $REPO_ROOT"
echo "Output Directory: $OUT_DIR"

mkdir -p "$OUT_DIR"

# Clean up working directories
rm -rf "$WORK_DIR" "$PROFILE_DIR"
mkdir -p "$WORK_DIR" "$PROFILE_DIR"

# 1. Base our profile on official archiso releng config if available
TEMP_PKGS="/tmp/releng-packages.list"
rm -f "$TEMP_PKGS"
if [ -d /usr/share/archiso/configs/releng ]; then
  echo "Copying baseline releng profile..."
  cp -r /usr/share/archiso/configs/releng/* "$PROFILE_DIR/"
  if [ -f "$PROFILE_DIR/packages.x86_64" ]; then
    cp "$PROFILE_DIR/packages.x86_64" "$TEMP_PKGS"
  fi
fi

# 2. Overlay Gnomarchy custom configurations
echo "Overlaying Gnomarchy custom configurations..."
cp -r "$CONFIGS_DIR/"* "$PROFILE_DIR/"

# 3. Merge releng packages + custom packages and deduplicate
echo "Merging package manifests..."
if [ -f "$TEMP_PKGS" ] && [ -f "$CONFIGS_DIR/packages.x86_64" ]; then
  cat "$TEMP_PKGS" "$CONFIGS_DIR/packages.x86_64" | grep -v '^#' | grep -v '^[[:space:]]*$' | tr -d '\r' | sort -u > "$PROFILE_DIR/packages.x86_64"
elif [ -f "$CONFIGS_DIR/packages.x86_64" ]; then
  grep -v '^#' "$CONFIGS_DIR/packages.x86_64" | grep -v '^[[:space:]]*$' | tr -d '\r' | sort -u > "$PROFILE_DIR/packages.x86_64"
fi

# 4. Synchronize current repository into ISO root for offline/local install
echo "Syncing Gnomarchy files into live ISO filesystem..."
mkdir -p "$PROFILE_DIR/airootfs/root/gnomarchy"
rsync -a --exclude=".git" --exclude="out" --exclude="iso/work" "$REPO_ROOT/" "$PROFILE_DIR/airootfs/root/gnomarchy/"

# Ensure installer script permissions inside profile
chmod 755 "$PROFILE_DIR/airootfs/root/.automated_script.sh" 2>/dev/null || true
chmod +x "$PROFILE_DIR/airootfs/root/gnomarchy/bin"/* 2>/dev/null || true
chmod +x "$PROFILE_DIR/airootfs/root/gnomarchy/install.sh" 2>/dev/null || true

# 5. Run mkarchiso
echo -e "\n\033[1;36m==> Running mkarchiso to build Gnomarchy ISO...\033[0m"
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo -e "\n\033[1;32m✓ ISO Build Completed Successfully!\033[0m"
ls -lh "$OUT_DIR"/*.iso
