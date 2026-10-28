#!/bin/bash
# limine.conf generation. The render functions print; boot_write_conf puts the
# result on the ESP.

# Kernel names with both an image and an initramfs on the ESP, sorted.
boot_kernels() {
  local img name
  for img in "$BOOT_ESP"/vmlinuz-*; do
    [[ -f "$img" ]] || continue
    name="${img##*/vmlinuz-}"
    if [[ -f "$BOOT_ESP/initramfs-$name.img" ]]; then
      printf '%s\n' "$name"
    else
      boot_log "skipping $name: no initramfs-$name.img on the ESP"
    fi
  done | LC_ALL=C sort
}

# The kernel snapshots are recorded against: linux if installed, else the first.
boot_default_kernel() {
  local kernels
  kernels="$(boot_kernels)"
  if [[ -z "$kernels" ]]; then
    boot_log "no kernel with an initramfs in $BOOT_ESP"
    return 1
  fi
  if grep -qx linux <<<"$kernels"; then
    printf 'linux\n'
  else
    printf '%s\n' "${kernels%%$'\n'*}"
  fi
}

# Snapshot numbers that have a menu record, newest first.
boot_snapshot_numbers() {
  local f n
  for f in "$BOOT_ENTRIES"/*.conf; do
    [[ -f "$f" ]] || continue
    n="${f##*/}"
    n="${n%.conf}"
    if [[ "$n" =~ ^[0-9]+$ ]]; then printf '%s\n' "$n"; fi
  done | LC_ALL=C sort -rn
}

# /etc/kernel/cmdline with whitespace collapsed to single spaces.
boot_base_cmdline() {
  local -a words
  if [[ ! -f "$BOOT_CMDLINE" ]]; then
    boot_log "no $BOOT_CMDLINE"
    return 1
  fi
  read -ra words < <(tr -s '[:space:]' ' ' <"$BOOT_CMDLINE")
  if ((${#words[@]} == 0)); then
    boot_log "$BOOT_CMDLINE is empty"
    return 1
  fi
  printf '%s\n' "${words[*]}"
}

# boot_snapshot_cmdline BASE N — the base command line pointed at snapshot N,
# read-only under a tmpfs overlay.
boot_snapshot_cmdline() {
  local word found=0
  local -a words out=()
  read -ra words <<<"$1"
  for word in "${words[@]}"; do
    case "$word" in
      rw) out+=(ro) ;;
      rootflags=subvol=@ | rootflags=subvol=/@)
        out+=("rootflags=subvol=@snapshots/$2/snapshot")
        found=1
        ;;
      splash) ;;
      *) out+=("$word") ;;
    esac
  done
  if ((!found)); then
    boot_log "the base command line has no rootflags=subvol=@; cannot point it at snapshot $2"
    return 1
  fi
  out+=(systemd.volatile=overlay "gnomarchy.snapshot=$2")
  printf '%s\n' "${out[*]}"
}

# boot_snapshot_title N DATE DESCRIPTION — Limine's font is code page 437, so
# every byte of DATE and DESCRIPTION outside printable ASCII becomes a space.
boot_snapshot_title() {
  local LC_ALL=C date desc
  date="${2//[^ -~]/ }"
  desc="${3//[^ -~]/ }"
  if [[ -n "$desc" ]]; then
    printf '%s | %s | %s' "$1" "$date" "$desc"
  else
    printf '%s | %s' "$1" "$date"
  fi
}

# boot_snapshot_renderable N BASE — succeeds when snapshot N gets a menu entry:
# its record exists, its boot files are in the store and its command line
# derives. The default check and the render loop both call this, so they
# cannot disagree.
boot_snapshot_renderable() {
  local n="$1" base="$2"
  local -A e=()
  if ! boot_read_kv "$BOOT_ENTRIES/$n.conf" e; then
    boot_log "snapshot $n has no menu entry"
    return 1
  fi
  if [[ ! -f "$BOOT_STORE/${e[KERNEL_HASH]:-none}" || ! -f "$BOOT_STORE/${e[INITRAMFS_HASH]:-none}" ]]; then
    boot_log "snapshot $n: its boot files are missing from the store"
    return 1
  fi
  boot_snapshot_cmdline "$base" "$n" >/dev/null
}

# Limine entry paths separate levels with /; a title's own /, \ and # are
# escaped as Limine's default_entry documentation requires.
boot_escape_entry() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\//\\/}"
  s="${s//\#/\\#}"
  printf '%s' "$s"
}

# Colour lines from /etc/gnomarchy/boot-theme.conf. That file is writable by
# wheel, so every value must be plain hex or none of them is used.
boot_theme_lines() {
  local key i
  local -A t=()
  local -a normal=() bright=()
  if ! boot_read_kv "$BOOT_THEME" t; then
    boot_log "no $BOOT_THEME; the menu keeps Limine's own colours"
    return 0
  fi
  for key in BACKGROUND FOREGROUND ACCENT NORMAL_{0..7} BRIGHT_{0..7}; do
    if [[ ! "${t[$key]:-}" =~ ^[0-9a-fA-F]{6}$ ]]; then
      boot_log "$BOOT_THEME: $key is missing or not rrggbb; the menu keeps Limine's own colours"
      return 0
    fi
  done
  for i in {0..7}; do
    normal+=("${t[NORMAL_$i]}")
    bright+=("${t[BRIGHT_$i]}")
  done
  local IFS=';'
  printf 'interface_branding_colour: %s\n' "${t[ACCENT]}"
  printf 'term_palette: %s\n' "${normal[*]}"
  printf 'term_palette_bright: %s\n' "${bright[*]}"
  printf 'term_background: 00%s\n' "${t[BACKGROUND]}"
  printf 'term_foreground: %s\n' "${t[FOREGROUND]}"
}

# boot_render_entry TITLE KERNEL_PATH KERNEL_HASH MODULE_PATH MODULE_HASH CMDLINE
boot_render_entry() {
  printf '%s\n' \
    "$1" \
    "    protocol: linux" \
    "    kernel_path: boot():$2#$3" \
    "    module_path: boot():$4#$5" \
    "    kernel_cmdline: $6"
}

# boot_render_kernel TITLE KERNEL INITRAMFS_FILE CMDLINE — hashes ESP files.
boot_render_kernel() {
  local kh mh
  kh="$(boot_hash "$BOOT_ESP/vmlinuz-$2")" || return 1
  mh="$(boot_hash "$BOOT_ESP/$3")" || return 1
  boot_render_entry "$1" "/vmlinuz-$2" "$kh" "/$3" "$mh" "$4"
}

# boot_render [ID] — prints limine.conf. ID is snapshot:N or a kernel name;
# without one the default is the linux kernel.
boot_render() {
  local id="${1:-}" base kernel n title cmdline default_path shown=0
  local -a kernels snapshots
  local -A d=() e=()
  base="$(boot_base_cmdline)" || return 1
  mapfile -t kernels < <(boot_kernels)
  if ((${#kernels[@]} == 0)); then
    boot_log "no kernel with an initramfs in $BOOT_ESP"
    return 1
  fi
  mapfile -t snapshots < <(boot_snapshot_numbers)

  case "$id" in
    "")
      default_path="Gnomarchy/$(boot_default_kernel)" || return 1
      ;;
    snapshot:*)
      n="${id#snapshot:}"
      if ! boot_snapshot_renderable "$n" "$base"; then
        boot_log "snapshot $n is not in the menu, so it cannot be the default"
        return 1
      fi
      boot_read_kv "$BOOT_ENTRIES/$n.conf" d
      title="$(boot_snapshot_title "$n" "${d[DATE]:-}" "${d[DESCRIPTION]:-}")"
      default_path="Gnomarchy/Snapshots/$(boot_escape_entry "$title")"
      ;;
    *)
      if ! printf '%s\n' "${kernels[@]}" | grep -qxF -- "$id"; then
        boot_log "no kernel named $id"
        return 1
      fi
      default_path="Gnomarchy/$(boot_escape_entry "$id")"
      ;;
  esac

  printf '%s\n' \
    "# Generated by gnomarchy-boot; rewritten on every kernel update, snapshot and" \
    "# theme change. Edit /etc/kernel/cmdline, not this file." \
    "timeout: 3" \
    "default_entry: $default_path" \
    "interface_branding: Gnomarchy"
  boot_theme_lines
  printf '\n/+Gnomarchy\n'

  for kernel in "${kernels[@]}"; do
    boot_render_kernel "//$kernel" "$kernel" "initramfs-$kernel.img" "$base" || return 1
    if [[ -f "$BOOT_ESP/initramfs-$kernel-fallback.img" ]]; then
      boot_render_kernel "//$kernel (fallback)" "$kernel" "initramfs-$kernel-fallback.img" "$base" || return 1
    fi
  done

  for n in "${snapshots[@]}"; do
    # A broken record must not take the whole menu with it.
    if ! boot_snapshot_renderable "$n" "$base"; then
      boot_log "snapshot $n left out of the menu"
      continue
    fi
    e=()
    boot_read_kv "$BOOT_ENTRIES/$n.conf" e
    cmdline="$(boot_snapshot_cmdline "$base" "$n")" || return 1
    # The folder heading appears only once an entry goes under it.
    if ((!shown)); then
      printf '//Snapshots\n'
      shown=1
    fi
    title="$(boot_snapshot_title "$n" "${e[DATE]:-}" "${e[DESCRIPTION]:-}")"
    boot_render_entry "///$title" \
      "/gnomarchy/store/${e[KERNEL_HASH]}" "${e[KERNEL_HASH]}" \
      "/gnomarchy/store/${e[INITRAMFS_HASH]}" "${e[INITRAMFS_HASH]}" \
      "$cmdline"
  done
}

# boot_write_conf [ID] — renders to a temporary file and renames it over
# limine.conf, so a failure never leaves a half-written menu.
boot_write_conf() {
  local tmp="$BOOT_ESP/limine.conf.new"
  if ! boot_render "${1:-}" >"$tmp"; then
    rm -f "$tmp"
    boot_log "limine.conf left unchanged"
    return 1
  fi
  sync "$tmp"
  mv -f "$tmp" "$BOOT_ESP/limine.conf"
}
