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
# Exclude anything a CI job may leave in the repo root; the whole tree is
# copied into the image, and the smoke test shipped its OVMF_VARS.fd this way.
rsync -a \
  --exclude=".git" --exclude="out" --exclude="iso/work" \
  --exclude="*.fd" --exclude="*.qcow2" --exclude="*.img" --exclude="*.iso" \
  --exclude="answers" --exclude="artifacts" --exclude="*.log" \
  --exclude="node_modules" --exclude=".wrangler" --exclude="__pycache__" \
  "$REPO_ROOT/" "$PROFILE_DIR/airootfs/root/gnomarchy/"

# Record which commit this image was built from.
#
# The rsync above drops .git, so the installed tree cannot tell what it is a
# copy of. install/config/repository.sh needs that: it turns the deployed
# directory into a git repository, and without knowing the commit it assumed
# `main`, then ran `git clean` and `git checkout -- .` against it. On an image
# built from any other branch that silently deleted every file main does not
# have and reverted every file the branch changed -- so the smoke test was
# verifying main rather than the branch under test, and the installer was
# rewriting its own scripts while bash was still reading them.
if git -C "$REPO_ROOT" rev-parse HEAD >/dev/null 2>&1; then
  git -C "$REPO_ROOT" rev-parse HEAD > "$PROFILE_DIR/airootfs/root/gnomarchy/install/.build-commit"
  echo "Image records build commit $(git -C "$REPO_ROOT" rev-parse --short HEAD)"
else
  echo "No git metadata in $REPO_ROOT; the installed repository will track main."
fi

# Ensure installer script permissions inside profile
chmod 755 "$PROFILE_DIR/airootfs/root/.automated_script.sh" 2>/dev/null || true
chmod +x "$PROFILE_DIR/airootfs/root/gnomarchy/bin"/* 2>/dev/null || true
chmod +x "$PROFILE_DIR/airootfs/root/gnomarchy/install.sh" 2>/dev/null || true

# Pre-populate bundled wallpapers into ISO live filesystem
echo "Installing bundled wallpapers to ISO rootfs..."
mkdir -p "$PROFILE_DIR/airootfs/usr/share/backgrounds/gnomarchy"
for bg in "$REPO_ROOT"/themes/*/backgrounds/*; do
  if [ -f "$bg" ]; then
    cp -f "$bg" "$PROFILE_DIR/airootfs/usr/share/backgrounds/gnomarchy/" 2>/dev/null || true
  fi
done
chmod 755 "$PROFILE_DIR/airootfs/usr/share/backgrounds/gnomarchy" 2>/dev/null || true
chmod 644 "$PROFILE_DIR/airootfs/usr/share/backgrounds/gnomarchy"/* 2>/dev/null || true

# 5. Run mkarchiso
echo -e "\n\033[1;36m==> Running mkarchiso to build Gnomarchy ISO...\033[0m"
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo -e "\n\033[1;32m✓ ISO Build Completed Successfully!\033[0m"
ls -lh "$OUT_DIR"/*.iso
