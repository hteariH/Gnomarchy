#!/bin/bash
# Limine onto the ESP and the disk. Run by the installer and by the pacman
# hook whenever the limine package changes.

boot_install() {
  local disk part esp pkname partn efivars="${GNOMARCHY_BOOT_EFIVARS:-/sys/firmware/efi/efivars}"
  local -A conf=()
  local nvram
  boot_read_kv "$BOOT_CONF" conf || boot_die "no $BOOT_CONF; the installer writes it"
  if [[ -z "$BOOT_ROOT" ]]; then
    # On a real system the disk and partition come from where the ESP is
    # mounted now: boot.conf can be stale, and the NVRAM entry must name the
    # partition the firmware will actually boot from.
    esp="$(findmnt -no SOURCE "$BOOT_ESP")" || boot_die "$BOOT_ESP is not a mounted partition"
    pkname="$(lsblk -no PKNAME "$esp")" || boot_die "cannot find the disk holding $esp"
    partn="$(lsblk -no PARTN "$esp")" || boot_die "cannot find the partition number of $esp"
    [[ -n "$pkname" && -n "$partn" ]] || boot_die "cannot find the disk and partition number of $esp"
    disk="/dev/$pkname"
    part="$partn"
    if [[ "${conf[DISK]:-}" != "$disk" || "${conf[ESP_PART]:-}" != "$part" ]]; then
      boot_log "$BOOT_CONF says DISK=${conf[DISK]:-} ESP_PART=${conf[ESP_PART]:-}; the ESP is $esp, so using $disk partition $part"
    fi
  else
    disk="${conf[DISK]:-}"
    part="${conf[ESP_PART]:-2}"
    [[ -n "$disk" ]] || boot_die "$BOOT_CONF has no DISK="
  fi
  [[ -b "$disk" || -n "$BOOT_ROOT" ]] || boot_die "$disk is not a block device"
  [[ -f "$BOOT_LIMINE_SHARE/BOOTX64.EFI" ]] || boot_die "limine is not installed: no $BOOT_LIMINE_SHARE/BOOTX64.EFI"

  # UEFI. The removable-media path boots on any firmware; the NVRAM entry
  # below is a nicety on top of it.
  install -Dm644 "$BOOT_LIMINE_SHARE/BOOTX64.EFI" "$BOOT_ESP/EFI/BOOT/BOOTX64.EFI"
  install -Dm644 "$BOOT_LIMINE_SHARE/BOOTIA32.EFI" "$BOOT_ESP/EFI/BOOT/BOOTIA32.EFI"
  install -Dm644 "$BOOT_LIMINE_SHARE/BOOTX64.EFI" "$BOOT_ESP/EFI/limine/BOOTX64.EFI"

  # BIOS, whatever the firmware: the disk has a BIOS boot partition, so it
  # boots both ways, including after a move to another machine.
  install -Dm644 "$BOOT_LIMINE_SHARE/limine-bios.sys" "$BOOT_ESP/limine-bios.sys"
  limine bios-install "$disk"

  if [[ -d "$efivars" ]]; then
    # The output is captured first: grep -q exiting early would SIGPIPE
    # efibootmgr, and pipefail would then read a present entry as absent.
    if nvram="$(efibootmgr)" && grep -qE '^Boot[0-9A-Fa-f]{4}\*? Gnomarchy([[:space:]]|$)' <<<"$nvram"; then
      boot_log "the NVRAM entry Gnomarchy is already there"
    elif efibootmgr --create --disk "$disk" --part "$part" \
      --loader '\EFI\limine\BOOTX64.EFI' --label Gnomarchy >/dev/null; then
      boot_log "created the NVRAM entry Gnomarchy"
    else
      boot_log "warning: no NVRAM entry written; the firmware still boots EFI/BOOT/BOOTX64.EFI"
    fi
  fi
}
