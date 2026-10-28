#!/bin/bash
# gnomarchy-boot against a throwaway tree: limine.conf generation, snapshot
# entries, the ESP budget, Limine installation, snapper setup and the plugin.
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO="$PWD"
# shellcheck source=iso/tests/lib/assert.sh
source iso/tests/lib/assert.sh
# shellcheck source=default/boot/lib/palette.sh
source default/boot/lib/palette.sh

BOOT="$REPO/default/boot/gnomarchy-boot"
FIXTURES="$REPO/iso/tests/fixtures/boot"
export TZ=UTC
KVERS=(6.17.5-arch1-1 6.17.6-arch1-1 6.17.7-arch1-1)
PAD_KB=0

# Fixture contents are a function of the kernel version, so normalize() can
# turn any hash back into a readable name.
kernel_bytes() {
  printf 'kernel %s\n' "$1"
  if ((PAD_KB)); then head -c $((PAD_KB * 1024)) /dev/zero; fi
}
initramfs_bytes() {
  printf 'initramfs for %s\n' "$1"
  if ((PAD_KB)); then head -c $((PAD_KB * 1024)) /dev/zero; fi
}
fallback_bytes() { printf 'fallback initramfs for %s\n' "$1"; }

# set_esp_kernel VERSION — the ESP's linux kernel and initramfs become VERSION.
set_esp_kernel() {
  kernel_bytes "$1" >"$T/boot/vmlinuz-linux"
  initramfs_bytes "$1" >"$T/boot/initramfs-linux.img"
}

new_tree() {
  T="$(mktemp -d)"
  export GNOMARCHY_BOOT_ROOT="$T"
  mkdir -p "$T/boot" "$T/etc/kernel" "$T/etc/gnomarchy" "$T/.snapshots"
  set_esp_kernel "${KVERS[0]}"
  echo 'root=UUID=1111-2222 rw rootflags=subvol=@ quiet splash' >"$T/etc/kernel/cmdline"
  boot_palette_from_alacritty "$REPO/themes/tokyo-night/alacritty.toml" >"$T/etc/gnomarchy/boot-theme.conf"
}

# add_snapshot N DATE DESCRIPTION [KERNEL_VERSION] — a snapper snapshot as
# snapper leaves it: info.xml plus the subvolume with its kernel modules.
add_snapshot() {
  local n="$1" ver="${4:-${KVERS[0]}}"
  mkdir -p "$T/.snapshots/$n/snapshot/usr/lib/modules/$ver"
  kernel_bytes "$ver" >"$T/.snapshots/$n/snapshot/usr/lib/modules/$ver/vmlinuz"
  cat >"$T/.snapshots/$n/info.xml" <<EOF
<?xml version="1.0"?>
<snapshot>
  <type>single</type>
  <num>$n</num>
  <date>$2</date>
  <description>$3</description>
</snapshot>
EOF
}

# normalize FILE — every fixture hash replaced by <vmlinuz VER> and friends.
normalize() {
  local out ver h
  out="$(<"$1")"
  for ver in "${KVERS[@]}"; do
    h="$(kernel_bytes "$ver" | b2sum | cut -d' ' -f1)"
    out="${out//$h/<vmlinuz $ver>}"
    h="$(initramfs_bytes "$ver" | b2sum | cut -d' ' -f1)"
    out="${out//$h/<initramfs $ver>}"
    h="$(fallback_bytes "$ver" | b2sum | cut -d' ' -f1)"
    out="${out//$h/<fallback $ver>}"
  done
  printf '%s\n' "$out"
}

golden() { # LABEL NAME
  normalize "$T/boot/limine.conf" >"$T/normalized.conf"
  t_golden "$1" "$T/normalized.conf" "$FIXTURES/$2"
}

conf_has() { grep -qxF -- "$1" "$T/boot/limine.conf"; }

echo "--- one kernel"
new_tree
t_true "update succeeds" "$BOOT" update
golden "single kernel menu" single.conf

echo "--- fallback image and a second kernel"
fallback_bytes "${KVERS[0]}" >"$T/boot/initramfs-linux-fallback.img"
printf 'lts kernel\n' >"$T/boot/vmlinuz-linux-lts"
printf 'lts initramfs\n' >"$T/boot/initramfs-linux-lts.img"
"$BOOT" update
t_true "fallback entry present" conf_has "//linux (fallback)"
t_true "fallback entry uses the fallback image" grep -q "module_path: boot():/initramfs-linux-fallback.img#" "$T/boot/limine.conf"
t_true "linux-lts gets its own entry" conf_has "//linux-lts"
t_true "the default stays linux" conf_has "default_entry: Gnomarchy/linux"
t_eq "linux is listed before linux-lts" "$(grep -E '^//linux(-lts)?$' "$T/boot/limine.conf" | tr '\n' ' ')" "//linux //linux-lts "

echo "--- a kernel without an initramfs is skipped"
printf 'orphan\n' >"$T/boot/vmlinuz-linux-zen"
"$BOOT" update 2>"$T/log"
t_false "no entry for linux-zen" conf_has "//linux-zen"
t_true "the skip is reported" grep -q "skipping linux-zen" "$T/log"

echo "--- theme file missing or malformed"
new_tree
rm "$T/etc/gnomarchy/boot-theme.conf"
"$BOOT" update 2>"$T/log"
t_false "no palette without a theme file" grep -q '^term_palette:' "$T/boot/limine.conf"
t_true "branding is still written" conf_has "interface_branding: Gnomarchy"
t_true "the missing theme is reported" grep -q "boot-theme.conf" "$T/log"
printf 'BACKGROUND=$(reboot)\n' >"$T/etc/gnomarchy/boot-theme.conf"
"$BOOT" update 2>"$T/log"
t_false "a malformed theme writes no palette" grep -q '^term_' "$T/boot/limine.conf"

echo "--- no kernel at all"
new_tree
"$BOOT" update
cp "$T/boot/limine.conf" "$T/before.conf"
rm "$T/boot/vmlinuz-linux"
t_false "update fails without a kernel" "$BOOT" update
t_true "limine.conf is left as it was" cmp -s "$T/before.conf" "$T/boot/limine.conf"
t_false "no temporary file is left behind" test -e "$T/boot/limine.conf.new"

t_done
