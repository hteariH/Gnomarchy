#!/bin/bash
# Installs Gnomarchy's boot tooling, root-owned, onto the system.
#
# Root must never execute scripts from a user's home, so everything that
# gnomarchy-boot, the snapper plugin and the pacman hooks run is copied out of
# the repository. Idempotent: the ISO installer runs it before installing the
# bootloader, install.sh runs it again, and so does every gnomarchy update.
#
#   sudo deploy.sh              onto /
#   DESTDIR=/tmp/x deploy.sh    onto a test tree
set -Eeuo pipefail

SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEST="${DESTDIR:-}"
[[ $EUID -eq 0 ]] || { echo "deploy.sh must run as root" >&2; exit 1; }

BOOT_CONF="$DEST/etc/gnomarchy/boot.conf"
if [[ ! -f "$BOOT_CONF" ]]; then
  echo "No $BOOT_CONF: this machine was not installed from the Gnomarchy ISO, so its bootloader is left alone."
  exit 0
fi

LIB_DIR="$DEST/usr/local/lib/gnomarchy/boot"
install -Dm755 "$SRC/gnomarchy-boot" "$LIB_DIR/gnomarchy-boot"
for f in "$SRC"/lib/*.sh; do
  install -Dm644 "$f" "$LIB_DIR/lib/${f##*/}"
done
install -Dm755 "$SRC/50-gnomarchy-boot" "$DEST/usr/lib/snapper/plugins/50-gnomarchy-boot"
install -Dm755 "$SRC/initcpio-post" "$DEST/etc/initcpio/post/gnomarchy-boot"
install -Dm644 "$SRC/00-gnomarchy-guard.hook" "$DEST/etc/pacman.d/hooks/00-gnomarchy-guard.hook"
install -Dm644 "$SRC/95-gnomarchy-boot.hook" "$DEST/etc/pacman.d/hooks/95-gnomarchy-boot.hook"
install -Dm644 "$SRC/95-gnomarchy-limine.hook" "$DEST/etc/pacman.d/hooks/95-gnomarchy-limine.hook"
install -Dm644 "$SRC/gnomarchy-overlay" "$DEST/etc/initcpio/install/gnomarchy-overlay"
install -Dm644 "$SRC/gnomarchy-boot-theme.path" "$DEST/etc/systemd/system/gnomarchy-boot-theme.path"
install -Dm644 "$SRC/gnomarchy-boot-theme.service" "$DEST/etc/systemd/system/gnomarchy-boot-theme.service"
install -Dm644 "$SRC/snapshot-notify.desktop" "$DEST/etc/xdg/autostart/gnomarchy-snapshot-notify.desktop"

# The initramfs. sd-encrypt only where there is something to open; plymouth
# after systemd and before the crypt hook, so the passphrase prompt is drawn.
encrypt=""
if grep -qx 'ENCRYPTED=1' "$BOOT_CONF"; then encrypt=" sd-encrypt"; fi
install -Dm644 /dev/null "$DEST/etc/mkinitcpio.conf.d/gnomarchy.conf"
cat >"$DEST/etc/mkinitcpio.conf.d/gnomarchy.conf" <<EOF
# Written by Gnomarchy's default/boot/deploy.sh from /etc/gnomarchy/boot.conf.
HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block${encrypt} filesystems fsck gnomarchy-overlay)
EOF

# The one file a user writes: gnomarchy-theme-set, as a member of wheel. It is
# parsed as data and never executed.
if [[ ! -f "$DEST/etc/gnomarchy/boot-theme.conf" ]]; then
  install -m664 -o root -g wheel /dev/null "$DEST/etc/gnomarchy/boot-theme.conf"
fi
chown root:wheel "$DEST/etc/gnomarchy/boot-theme.conf"
chmod 664 "$DEST/etc/gnomarchy/boot-theme.conf"

systemctl --root="${DEST:-/}" enable gnomarchy-boot-theme.path
# On a running system (gnomarchy update) systemd must reread the units just
# replaced. A chroot and a test tree have no systemd running to tell.
if [[ -z "$DEST" && -d /run/systemd/system ]]; then
  systemctl daemon-reload
fi
echo "Boot tooling deployed."
