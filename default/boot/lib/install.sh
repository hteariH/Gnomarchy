#!/bin/bash
# Limine onto the ESP and the disk. Run by the installer and by the pacman
# hook whenever the limine package changes.

boot_install() {
  local disk efivars="${GNOMARCHY_BOOT_EFIVARS:-/sys/firmware/efi/efivars}"
  local -A conf=()
  local nvram
  boot_read_kv "$BOOT_CONF" conf || boot_die "no $BOOT_CONF; the installer writes it"
  disk="${conf[DISK]:-}"
  [[ -n "$disk" ]] || boot_die "$BOOT_CONF has no DISK="
  [[ -b "$disk" || -n "$BOOT_ROOT" ]] || boot_die "$disk from $BOOT_CONF is not a block device"
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
    elif efibootmgr --create --disk "$disk" --part "${conf[ESP_PART]:-2}" \
      --loader '\EFI\limine\BOOTX64.EFI' --label Gnomarchy >/dev/null; then
      boot_log "created the NVRAM entry Gnomarchy"
    else
      boot_log "warning: no NVRAM entry written; the firmware still boots EFI/BOOT/BOOTX64.EFI"
    fi
  fi
}
