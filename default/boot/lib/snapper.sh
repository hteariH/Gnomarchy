#!/bin/bash
# The root snapper config and snapshot 1, without D-Bus.
#
# `snapper create-config` needs snapperd over D-Bus, which arch-chroot does not
# have, and refuses a /.snapshots that already exists - ours is the @snapshots
# subvolume. So the config is written from snapper's own template. Run last in
# the installation: snap-pac does nothing until this config exists.

boot_snapper_init() {
  local template="$BOOT_ROOT/usr/share/snapper/config-templates/default"
  local config="$BOOT_ROOT/etc/snapper/configs/root"
  local confd="$BOOT_ROOT/etc/conf.d/snapper"
  local kv

  [[ -f "$template" ]] || boot_die "snapper is not installed: no $template"

  if [[ ! -f "$config" ]]; then
    install -Dm640 "$template" "$config"
    sed -i \
      -e 's|^SUBVOLUME=.*|SUBVOLUME="/"|' \
      -e 's|^FSTYPE=.*|FSTYPE="btrfs"|' \
      -e 's|^ALLOW_GROUPS=.*|ALLOW_GROUPS="wheel"|' \
      -e 's|^TIMELINE_CREATE=.*|TIMELINE_CREATE="no"|' \
      -e 's|^NUMBER_LIMIT=.*|NUMBER_LIMIT="10"|' \
      -e 's|^NUMBER_LIMIT_IMPORTANT=.*|NUMBER_LIMIT_IMPORTANT="5"|' \
      "$config"
    for kv in 'SUBVOLUME="/"' 'FSTYPE="btrfs"' 'ALLOW_GROUPS="wheel"' 'TIMELINE_CREATE="no"' \
      'NUMBER_LIMIT="10"' 'NUMBER_LIMIT_IMPORTANT="5"'; do
      grep -qxF "$kv" "$config" || boot_die "snapper's template has no ${kv%%=*} line; check $config"
    done
    boot_log "wrote $config"
  fi

  if [[ ! -f "$confd" ]] || ! grep -qE '^SNAPPER_CONFIGS="(.* )?root( .*)?"$' "$confd"; then
    install -Dm644 /dev/null "$confd"
    printf 'SNAPPER_CONFIGS="root"\n' >"$confd"
  fi

  systemctl enable snapper-cleanup.timer

  # Snapshot 1 has no cleanup algorithm, so number cleanup never removes it.
  # Captured before grep: grep -q exiting early would SIGPIPE snapper, and
  # pipefail would then read an existing snapshot as absent.
  local listed
  listed="$(snapper --no-dbus --csvout --no-headers -c root list --columns description)"
  if ! grep -qxF 'Gnomarchy installed' <<<"$listed"; then
    snapper --no-dbus -c root create --description 'Gnomarchy installed'
  fi
}
