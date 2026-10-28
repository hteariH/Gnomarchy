#!/bin/bash
# deploy.sh onto a throwaway root. Needs root, a wheel group and systemctl,
# which archlinux:latest has.
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO="$PWD"
# shellcheck source=iso/tests/lib/assert.sh
source iso/tests/lib/assert.sh

D="$(mktemp -d)"
mkdir -p "$D/etc/gnomarchy"

# deploy.sh and systemctl are chatty; their output goes to a log the test reads.
run_deploy() {
  env DESTDIR="$D" bash "$REPO/default/boot/deploy.sh" >"$D/deploy.log" 2>&1
}

echo "--- not installed from the ISO"
t_true "deploy succeeds without boot.conf" run_deploy
t_false "and installs nothing" test -e "$D/usr/local/lib/gnomarchy/boot/gnomarchy-boot"

echo "--- an encrypted ISO install"
printf 'DISK=/dev/vda\nESP_PART=2\nENCRYPTED=1\n' >"$D/etc/gnomarchy/boot.conf"
t_true "deploy succeeds" run_deploy
t_true "deploy reports completion" grep -qx 'Boot tooling deployed.' "$D/deploy.log"
for f in usr/local/lib/gnomarchy/boot/gnomarchy-boot usr/lib/snapper/plugins/50-gnomarchy-boot; do
  t_true "$f is executable" test -x "$D/$f"
done
for f in usr/local/lib/gnomarchy/boot/lib/common.sh usr/local/lib/gnomarchy/boot/lib/palette.sh \
  etc/pacman.d/hooks/95-gnomarchy-boot.hook etc/pacman.d/hooks/95-gnomarchy-limine.hook \
  etc/initcpio/install/gnomarchy-overlay etc/systemd/system/gnomarchy-boot-theme.path \
  etc/systemd/system/gnomarchy-boot-theme.service etc/xdg/autostart/gnomarchy-snapshot-notify.desktop; do
  t_true "$f is installed" test -f "$D/$f"
done
t_true "the theme path unit is enabled" test -L "$D/etc/systemd/system/paths.target.wants/gnomarchy-boot-theme.path"
t_eq "the theme file is root:wheel 664" "$(stat -c '%U:%G %a' "$D/etc/gnomarchy/boot-theme.conf")" "root:wheel 664"
t_true "sd-encrypt is in HOOKS" grep -q ' sd-encrypt ' "$D/etc/mkinitcpio.conf.d/gnomarchy.conf"
t_true "gnomarchy-overlay is in HOOKS" grep -q ' gnomarchy-overlay)' "$D/etc/mkinitcpio.conf.d/gnomarchy.conf"
t_false "no autostart phase (CLAUDE.md)" grep -q X-GNOME-Autostart-Phase "$D/etc/xdg/autostart/gnomarchy-snapshot-notify.desktop"

echo "--- a second run keeps the theme and follows boot.conf"
echo 'BACKGROUND=123456' >"$D/etc/gnomarchy/boot-theme.conf"
sed -i 's/ENCRYPTED=1/ENCRYPTED=0/' "$D/etc/gnomarchy/boot.conf"
t_true "second deploy succeeds" run_deploy
t_true "the theme file is kept" grep -qx 'BACKGROUND=123456' "$D/etc/gnomarchy/boot-theme.conf"
t_false "sd-encrypt is gone on an unencrypted install" grep -q sd-encrypt "$D/etc/mkinitcpio.conf.d/gnomarchy.conf"

rm -rf "$D"
t_done
