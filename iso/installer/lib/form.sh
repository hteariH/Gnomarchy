#!/bin/bash
# Installer field rules, shared by the interactive form and the unattended
# answers. No UI and no side effects: iso/tests/test-installer-validate.sh runs
# them directly.

INSTALLER_LIB="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_KEYMAPS="$INSTALLER_LIB/keymaps.tsv"
INSTALLER_ZONEINFO="${INSTALLER_ZONEINFO:-/usr/share/zoneinfo}"

valid_username() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ && "$1" != root ]]; }

# One RFC 1123 label: letters, digits and inner hyphens, at most 63.
valid_hostname() { [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; }

valid_timezone() {
  [[ "$1" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ && -f "$INSTALLER_ZONEINFO/$1" ]]
}

# keymap_fields ID — the table row as KEY=value lines ('-' becomes empty).
keymap_fields() {
  awk -F'\t' -v id="$1" '
    !/^#/ && $1 == id {
      for (i = 3; i <= 5; i++) if ($i == "-") $i = ""
      printf "XKB_LAYOUT=%s\nXKB_VARIANT=%s\nCONSOLE_KEYMAP=%s\nCONSOLE_FONT=%s\nLATIN=%s\nLABEL=%s\n",
        $2, $3, $4, $5, $6, $7
      found = 1
      exit
    }
    END { exit !found }' "$INSTALLER_KEYMAPS"
}

# keymap_load ID — sets KB_XKB_LAYOUT, KB_XKB_VARIANT, KB_CONSOLE_KEYMAP,
# KB_CONSOLE_FONT, KB_LATIN and KB_LABEL.
keymap_load() {
  local fields line
  fields="$(keymap_fields "$1")" || return 1
  while IFS= read -r line; do
    printf -v "KB_${line%%=*}" '%s' "${line#*=}"
  done <<<"$fields"
}

# Lines for gum filter: "Label  [id]".
keymap_menu() {
  awk -F'\t' '!/^#/ && NF >= 7 { printf "%s  [%s]\n", $7, $1 }' "$INSTALLER_KEYMAPS"
}

keymap_id_from_menu() {
  local re='\[([^]]+)\]$'
  [[ "$1" =~ $re ]] && printf '%s\n' "${BASH_REMATCH[1]}"
}

# installer_check_answers — validates the GNOMARCHY_* answers read from
# gnomarchy-unattended.conf and fills the defaults. Prints every problem, not
# just the first, because each CI round trip is long.
installer_check_answers() {
  local -a problems=()
  GNOMARCHY_FULLNAME="${GNOMARCHY_FULLNAME:-}"
  GNOMARCHY_HOSTNAME="${GNOMARCHY_HOSTNAME:-gnomarchy}"
  GNOMARCHY_TIMEZONE="${GNOMARCHY_TIMEZONE:-UTC}"
  GNOMARCHY_KEYMAP="${GNOMARCHY_KEYMAP:-us}"
  GNOMARCHY_ENCRYPT="${GNOMARCHY_ENCRYPT:-n}"
  GNOMARCHY_DISK_PASSWORD="${GNOMARCHY_DISK_PASSWORD:-${GNOMARCHY_PASSWORD:-}}"

  [[ -n "${GNOMARCHY_DISK:-}" ]] || problems+=("GNOMARCHY_DISK is not set")
  valid_username "${GNOMARCHY_USERNAME:-}" ||
    problems+=("GNOMARCHY_USERNAME '${GNOMARCHY_USERNAME:-}' is not a valid username")
  [[ -n "${GNOMARCHY_PASSWORD:-}" ]] || problems+=("GNOMARCHY_PASSWORD is not set")
  valid_hostname "$GNOMARCHY_HOSTNAME" || problems+=("GNOMARCHY_HOSTNAME '$GNOMARCHY_HOSTNAME' is not a valid hostname")
  valid_timezone "$GNOMARCHY_TIMEZONE" || problems+=("GNOMARCHY_TIMEZONE '$GNOMARCHY_TIMEZONE' is not a timezone")
  keymap_fields "$GNOMARCHY_KEYMAP" >/dev/null ||
    problems+=("GNOMARCHY_KEYMAP '$GNOMARCHY_KEYMAP' is not in keymaps.tsv")
  case "${GNOMARCHY_ENCRYPT,,}" in
    y | yes) GNOMARCHY_ENCRYPT=y ;;
    n | no) GNOMARCHY_ENCRYPT=n ;;
    *) problems+=("GNOMARCHY_ENCRYPT must be y or n, got '$GNOMARCHY_ENCRYPT'") ;;
  esac

  ((${#problems[@]} == 0)) && return 0
  printf 'answers: %s\n' "${problems[@]}" >&2
  return 1
}
