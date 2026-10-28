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
  # A large ESP size keeps the budget out of every case that is not about it;
  # otherwise usage would come from the host's df.
  export GNOMARCHY_BOOT_ESP_SIZE_KB=10000000
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
t_false "update fails without a kernel" "$BOOT" update 2>"$T/log"
t_true "the missing kernel is reported" grep -q "no kernel with an initramfs" "$T/log"
t_true "limine.conf is left as it was" cmp -s "$T/before.conf" "$T/boot/limine.conf"
t_false "no temporary file is left behind" test -e "$T/boot/limine.conf.new"

# non_ascii FILE — succeeds when FILE holds any byte outside printable ASCII.
non_ascii() { LC_ALL=C grep -q '[^ -~]' "$1"; }

echo "--- snapshot heading is ASCII and matches the default entry"
new_tree
mkdir -p "$T/boot/gnomarchy/store" "$T/boot/gnomarchy/entries"
echo kh >"$T/boot/gnomarchy/store/kh"
echo ih >"$T/boot/gnomarchy/store/ih"
# DESCRIPTION holds a two-byte UTF-8 e-acute and a tab; both become spaces.
printf 'KERNEL_HASH=kh\nINITRAMFS_HASH=ih\nDATE=2026-10-28 10:00\nDESCRIPTION=caf\xc3\xa9 b\tz\n' >"$T/boot/gnomarchy/entries/7.conf"
LC_ALL=C.UTF-8 "$BOOT" update
t_true "the heading replaces each non-ASCII byte and the tab with a space" conf_has "///7 | 2026-10-28 10:00 | caf   b z"
t_false "the menu holds no byte outside printable ASCII" non_ascii "$T/boot/limine.conf"
LC_ALL=C.UTF-8 "$BOOT" update --default snapshot:7
t_true "the default names the same heading" conf_has "default_entry: Gnomarchy/Snapshots/7 | 2026-10-28 10:00 | caf   b z"

echo "--- a default must name a snapshot that is in the menu"
new_tree
mkdir -p "$T/boot/gnomarchy/store" "$T/boot/gnomarchy/entries"
echo kh >"$T/boot/gnomarchy/store/kh"
printf 'KERNEL_HASH=kh\nINITRAMFS_HASH=ih\nDATE=2026-10-28 10:00\nDESCRIPTION=half-copied\n' >"$T/boot/gnomarchy/entries/8.conf"
"$BOOT" update 2>"$T/log"
t_true "the snapshot with a missing boot file is left out" grep -q "snapshot 8: its boot files are missing" "$T/log"
t_false "no empty Snapshots folder when every snapshot is skipped" conf_has "//Snapshots"
cp "$T/boot/limine.conf" "$T/before.conf"
t_false "a default on the skipped snapshot fails" "$BOOT" update --default snapshot:8 2>"$T/log"
t_true "the failed default is reported" grep -q "snapshot 8" "$T/log"
t_true "limine.conf is left as it was after the failed default" cmp -s "$T/before.conf" "$T/boot/limine.conf"
echo ih >"$T/boot/gnomarchy/store/ih"
t_true "the same default succeeds once its files are in the store" "$BOOT" update --default snapshot:8
t_true "the default names the snapshot" conf_has "default_entry: Gnomarchy/Snapshots/8 | 2026-10-28 10:00 | half-copied"

echo "--- snapshots across a kernel upgrade"
new_tree
add_snapshot 2 "2026-10-27 09:15:00" "before upgrade"
t_true "snapshot 2 is added" "$BOOT" snapshot-add 2 2>"$T/log"
set_esp_kernel "${KVERS[1]}"
add_snapshot 3 "2026-10-28 14:02:11" "pacman -Syu" "${KVERS[1]}"
"$BOOT" snapshot-add 3 2>"$T/log"
add_snapshot 4 "2026-10-28 18:30:45" "manual" "${KVERS[1]}"
"$BOOT" snapshot-add 4 2>"$T/log"
golden "snapshot menu, newest first" snapshots.conf
t_eq "two kernels, two initramfs images: four store files" "$(find "$T/boot/gnomarchy/store" -type f | wc -l)" "4"
t_true "the record names the module version" grep -qx "VERSION=${KVERS[1]}" "$T/boot/gnomarchy/entries/3.conf"

echo "--- descriptions are data"
add_snapshot 6 "2026-10-28 20:00:00" 'pacman -S a/b #1 &amp; $(reboot)' "${KVERS[1]}"
"$BOOT" snapshot-add 6 2>"$T/log"
t_true "XML entities are decoded, shell text is kept literally" \
  grep -qxF 'DESCRIPTION=pacman -S a/b #1 & $(reboot)' "$T/boot/gnomarchy/entries/6.conf"
t_true "--default snapshot:6 succeeds" "$BOOT" update --default snapshot:6
t_true "the default entry path is escaped" \
  conf_has 'default_entry: Gnomarchy/Snapshots/6 | 2026-10-28 20:00 | pacman -S a\/b \#1 & $(reboot)'
cp "$T/boot/limine.conf" "$T/before.conf"
t_false "--default for a snapshot without an entry fails" "$BOOT" update --default snapshot:99 2>"$T/log"
t_true "and leaves limine.conf alone" cmp -s "$T/before.conf" "$T/boot/limine.conf"
"$BOOT" update
t_true "a plain update returns the default to linux" conf_has "default_entry: Gnomarchy/linux"

echo "--- removing a snapshot"
t_true "snapshot-remove 2 succeeds" "$BOOT" snapshot-remove 2 2>"$T/log"
t_false "its record is gone" test -e "$T/boot/gnomarchy/entries/2.conf"
t_false "its entry is gone" grep -q '^///2 | ' "$T/boot/limine.conf"
t_eq "the old kernel left the store" "$(find "$T/boot/gnomarchy/store" -type f | wc -l)" "2"

echo "--- a snapshot without the ESP's kernel gets no entry"
add_snapshot 7 "2026-10-28 21:00:00" "foreign kernel" "${KVERS[2]}"
t_true "snapshot-add still succeeds" "$BOOT" snapshot-add 7 2>"$T/log"
t_false "but records nothing" test -e "$T/boot/gnomarchy/entries/7.conf"
t_true "and says why" grep -q "does not contain the ESP's vmlinuz-linux" "$T/log"

echo "--- a base command line without subvol=@"
new_tree
"$BOOT" update
echo 'root=UUID=1111-2222 rw quiet' >"$T/etc/kernel/cmdline"
add_snapshot 2 "2026-10-27 09:15:00" "x"
t_false "snapshot-add refuses" "$BOOT" snapshot-add 2 2>"$T/log"
t_false "and records nothing" test -e "$T/boot/gnomarchy/entries/2.conf"
t_true "the menu still updates" "$BOOT" update

echo "--- an info.xml without a date stores nothing"
new_tree
add_snapshot 2 "2026-10-27 09:15:00" "good"
"$BOOT" snapshot-add 2 2>"$T/log"
set_esp_kernel "${KVERS[1]}"
add_snapshot 3 "2026-10-28 14:02:11" "undated" "${KVERS[1]}"
sed -i '/<date>/d' "$T/.snapshots/3/info.xml"
t_false "snapshot-add refuses it" "$BOOT" snapshot-add 3 2>"$T/log"
t_true "and says why" grep -q "no readable date" "$T/log"
t_false "and records nothing" test -e "$T/boot/gnomarchy/entries/3.conf"
t_eq "and the store is unchanged" "$(find "$T/boot/gnomarchy/store" -type f | wc -l)" "2"

echo "--- a full ESP: a copy that does not fit records nothing"
PAD_KB=1
new_tree
add_snapshot 2 "2026-10-27 09:00:00" "full"
# ulimit -f caps file size, so cp fails the way it does on a full ESP.
t_false "snapshot-add fails when the copy does not fit" \
  bash -c 'ulimit -f 1; exec "$0" snapshot-add "$1"' "$BOOT" 2 2>"$T/log"
t_true "and says why" grep -q "no room on the ESP for vmlinuz-linux" "$T/log"
t_false "and records nothing" test -e "$T/boot/gnomarchy/entries/2.conf"
t_eq "and leaves no temporary file behind" "$(find "$T/boot" -name '*.tmp' | wc -l)" "0"
PAD_KB=0

echo "--- the ESP budget drops the oldest entries"
PAD_KB=100
new_tree
export GNOMARCHY_BOOT_ESP_SIZE_KB=900
add_snapshot 2 "2026-10-27 09:00:00" "a"
"$BOOT" snapshot-add 2 2>"$T/log"
set_esp_kernel "${KVERS[1]}"
add_snapshot 3 "2026-10-27 10:00:00" "b" "${KVERS[1]}"
"$BOOT" snapshot-add 3 2>"$T/log"
t_true "two snapshots fit" test -e "$T/boot/gnomarchy/entries/2.conf"
set_esp_kernel "${KVERS[2]}"
add_snapshot 4 "2026-10-27 11:00:00" "c" "${KVERS[2]}"
"$BOOT" snapshot-add 4 2>"$T/log"
t_false "the third pushes out the oldest" test -e "$T/boot/gnomarchy/entries/2.conf"
t_true "the newer two remain" test -e "$T/boot/gnomarchy/entries/3.conf" -a -e "$T/boot/gnomarchy/entries/4.conf"
t_true "the snapshot itself is untouched" test -d "$T/.snapshots/2/snapshot"
t_true "the drop is reported" grep -q "dropping the menu entry of snapshot 2" "$T/log"
export GNOMARCHY_BOOT_ESP_SIZE_KB=10000000
PAD_KB=0

echo "--- the snapper plugin"
new_tree
export GNOMARCHY_BOOT_BIN="$BOOT"
PLUGIN="$REPO/default/boot/50-gnomarchy-boot"
add_snapshot 5 "2026-10-28 08:00:00" "via plugin"
t_true "create-snapshot-post for / succeeds" bash "$PLUGIN" create-snapshot-post / btrfs 5 2>"$T/log"
t_true "and adds the entry" grep -q '^///5 | ' "$T/boot/limine.conf"
add_snapshot 8 "2026-10-28 08:00:00" "home"
bash "$PLUGIN" create-snapshot-post /home btrfs 8
t_false "other subvolumes are ignored" test -e "$T/boot/gnomarchy/entries/8.conf"
t_true "pre events are ignored" bash "$PLUGIN" create-snapshot-pre / btrfs 9
t_true "delete-snapshot-post removes" bash "$PLUGIN" delete-snapshot-post / btrfs 5 2>"$T/log"
t_false "the entry is gone" grep -q '^///5 | ' "$T/boot/limine.conf"
unset GNOMARCHY_BOOT_BIN

# stub NAME SCRIPT — a fake command in $T/bin that logs its arguments.
stub() {
  mkdir -p "$T/bin"
  printf '#!/bin/bash\necho "%s $*" >>"%s/calls"\n%s\n' "$1" "$T" "$2" >"$T/bin/$1"
  chmod +x "$T/bin/$1"
}

echo "--- install: Limine onto the ESP and the disk"
new_tree
mkdir -p "$T/usr/share/limine" "$T/efivars"
printf 'efi x64\n' >"$T/usr/share/limine/BOOTX64.EFI"
printf 'efi ia32\n' >"$T/usr/share/limine/BOOTIA32.EFI"
printf 'bios stage 2\n' >"$T/usr/share/limine/limine-bios.sys"
printf 'DISK=/dev/fake\nESP_PART=2\nENCRYPTED=0\n' >"$T/etc/gnomarchy/boot.conf"
stub limine ''
stub efibootmgr ''
export GNOMARCHY_BOOT_EFIVARS="$T/efivars"
PATH="$T/bin:$PATH" "$BOOT" install 2>"$T/log"
t_true "fallback EFI path" cmp -s "$T/usr/share/limine/BOOTX64.EFI" "$T/boot/EFI/BOOT/BOOTX64.EFI"
t_true "32-bit EFI path" cmp -s "$T/usr/share/limine/BOOTIA32.EFI" "$T/boot/EFI/BOOT/BOOTIA32.EFI"
t_true "NVRAM target path" cmp -s "$T/usr/share/limine/BOOTX64.EFI" "$T/boot/EFI/limine/BOOTX64.EFI"
t_true "BIOS stage 2 on the ESP" cmp -s "$T/usr/share/limine/limine-bios.sys" "$T/boot/limine-bios.sys"
t_true "limine bios-install ran on the disk" grep -qx "limine bios-install /dev/fake" "$T/calls"
t_true "an NVRAM entry was created" \
  grep -qxF 'efibootmgr --create --disk /dev/fake --part 2 --loader \EFI\limine\BOOTX64.EFI --label Gnomarchy' "$T/calls"
rm "$T/calls"
stub efibootmgr '[[ $# -eq 0 ]] && printf "Boot0001* Gnomarchy\tHD(2,GPT)\n"; exit 0'
PATH="$T/bin:$PATH" "$BOOT" install 2>"$T/log"
t_false "an existing NVRAM entry is kept" grep -q -- "--create" "$T/calls"
rm -rf "$T/efivars" "$T/calls"
PATH="$T/bin:$PATH" "$BOOT" install 2>"$T/log"
t_false "no NVRAM work on BIOS firmware" grep -q '^efibootmgr' "$T/calls"
t_true "bios-install still runs on BIOS firmware" grep -qx "limine bios-install /dev/fake" "$T/calls"
rm "$T/etc/gnomarchy/boot.conf"
t_false "install refuses without boot.conf" env PATH="$T/bin:$PATH" "$BOOT" install 2>"$T/log"
t_true "and says why" grep -qF "boot.conf; the installer writes it" "$T/log"
unset GNOMARCHY_BOOT_EFIVARS

echo "--- install: a failed NVRAM write is a warning"
new_tree
mkdir -p "$T/usr/share/limine" "$T/efivars"
printf 'efi x64\n' >"$T/usr/share/limine/BOOTX64.EFI"
printf 'efi ia32\n' >"$T/usr/share/limine/BOOTIA32.EFI"
printf 'bios stage 2\n' >"$T/usr/share/limine/limine-bios.sys"
printf 'DISK=/dev/fake\nESP_PART=2\nENCRYPTED=0\n' >"$T/etc/gnomarchy/boot.conf"
stub limine ''
stub efibootmgr '[[ $# -eq 0 ]] || exit 1'
export GNOMARCHY_BOOT_EFIVARS="$T/efivars"
t_true "the install still succeeds" env PATH="$T/bin:$PATH" "$BOOT" install 2>"$T/log"
t_true "and warns that the firmware boots the fallback" grep -qF "no NVRAM entry written" "$T/log"
t_true "the fallback EFI file is in place" cmp -s "$T/usr/share/limine/BOOTX64.EFI" "$T/boot/EFI/BOOT/BOOTX64.EFI"
unset GNOMARCHY_BOOT_EFIVARS

echo "--- snapper-init: root config and snapshot 1, no D-Bus"
new_tree
mkdir -p "$T/usr/share/snapper/config-templates"
printf '%s\n' 'SUBVOLUME="/"' 'FSTYPE="btrfs"' 'ALLOW_GROUPS=""' 'TIMELINE_CREATE="yes"' \
  'NUMBER_LIMIT="50"' 'NUMBER_LIMIT_IMPORTANT="10"' >"$T/usr/share/snapper/config-templates/default"
stub snapper ''
stub systemctl ''
PATH="$T/bin:$PATH" "$BOOT" snapper-init 2>"$T/log"
for kv in 'TIMELINE_CREATE="no"' 'NUMBER_LIMIT="10"' 'NUMBER_LIMIT_IMPORTANT="5"' 'ALLOW_GROUPS="wheel"'; do
  t_true "root config: $kv" grep -qxF "$kv" "$T/etc/snapper/configs/root"
done
t_true "SNAPPER_CONFIGS lists root" grep -qx 'SNAPPER_CONFIGS="root"' "$T/etc/conf.d/snapper"
t_true "the cleanup timer is enabled" grep -qx "systemctl enable snapper-cleanup.timer" "$T/calls"
t_true "snapshot 1 is created without D-Bus" \
  grep -qxF "snapper --no-dbus -c root create --description Gnomarchy installed" "$T/calls"
rm "$T/calls"
stub snapper '[[ " $* " == *" list "* ]] && echo "Gnomarchy installed"; exit 0'
PATH="$T/bin:$PATH" "$BOOT" snapper-init 2>"$T/log"
t_false "a second run creates no second snapshot" grep -q " create " "$T/calls"

echo "--- snapper-init adds root to an existing config list"
new_tree
mkdir -p "$T/usr/share/snapper/config-templates" "$T/etc/conf.d"
printf '%s\n' 'SUBVOLUME="/"' 'FSTYPE="btrfs"' 'ALLOW_GROUPS=""' 'TIMELINE_CREATE="yes"' \
  'NUMBER_LIMIT="50"' 'NUMBER_LIMIT_IMPORTANT="10"' >"$T/usr/share/snapper/config-templates/default"
printf 'SNAPPER_CONFIGS="home"\n' >"$T/etc/conf.d/snapper"
stub snapper ''
stub systemctl ''
PATH="$T/bin:$PATH" "$BOOT" snapper-init 2>"$T/log"
t_true "root is added and home is kept" grep -qxF 'SNAPPER_CONFIGS="home root"' "$T/etc/conf.d/snapper"

t_done
