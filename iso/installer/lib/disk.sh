#!/bin/bash
# Disks: which may be installed onto, and the partition names on them.

INSTALLER_MIN_DISK_BYTES=$((20 * 1024 * 1024 * 1024))

# lsblk_field FIELD LINE — one value from an `lsblk -P` line.
lsblk_field() {
  local re="(^| )$1=\"([^\"]*)\""
  if [[ "$2" =~ $re ]]; then printf '%s' "${BASH_REMATCH[2]}"; fi
}

# The disk the live system was booted from, never offered as a target.
boot_medium_disk() {
  local part parent
  # Not mounted with copytoram or PXE: then there is nothing to exclude.
  part="$(findmnt -no SOURCE /run/archiso/bootmnt)" || return 0
  parent="$(lsblk -no PKNAME "$part" | sed -n 1p)"
  printf '/dev/%s\n' "${parent:-${part#/dev/}}"
}

# disk_candidates — DEVICE<TAB>BYTES<TAB>DESCRIPTION per installable disk.
disk_candidates() {
  local boot line name size type ro model tran
  boot="$(boot_medium_disk)"
  while IFS= read -r line; do
    name="$(lsblk_field NAME "$line")"
    size="$(lsblk_field SIZE "$line")"
    type="$(lsblk_field TYPE "$line")"
    ro="$(lsblk_field RO "$line")"
    model="$(lsblk_field MODEL "$line")"
    tran="$(lsblk_field TRAN "$line")"
    [[ "$type" == disk && "$ro" == 0 ]] || continue
    [[ "$name" == /dev/zram* || "$name" == "$boot" ]] && continue
    printf '%s\t%s\t%s  %s  %s\n' "$name" "$size" \
      "$(numfmt --to=iec-i --suffix=B "$size")" "${model:-unknown model}" "$tran"
  done < <(lsblk -dnbpP -o NAME,SIZE,TYPE,RO,MODEL,TRAN)
}

# partition_path DISK N — /dev/vda 3 -> /dev/vda3, /dev/nvme0n1 3 -> /dev/nvme0n1p3
partition_path() {
  if [[ "$1" =~ [0-9]$ ]]; then printf '%sp%s\n' "$1" "$2"; else printf '%s%s\n' "$1" "$2"; fi
}

# Sets ESP_PART, ROOT_PART and FS_DEV from DISK and ENCRYPT.
disk_layout() {
  ESP_PART="$(partition_path "$DISK" 2)"
  ROOT_PART="$(partition_path "$DISK" 3)"
  FS_DEV="$ROOT_PART"
  if [[ "$ENCRYPT" == y ]]; then FS_DEV=/dev/mapper/cryptroot; fi
}
