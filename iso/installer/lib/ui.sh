#!/bin/bash
# Screens. Interactive mode draws them with gum; with UNATTENDED=1 they print
# plain lines, because CI reads them and nobody is there to answer.
# Only ASCII on screen: the live console's font has no check marks.

UI_BANNER='   ____  _   _  ___  __  __    _    ____   ____ _   ___   __
  / ___|| \ | |/ _ \|  \/  |  / \  |  _ \ / ___| | | \ \ / /
 | |  _ |  \| | | | | |\/| | / _ \ | |_) | |   | |_| |\ V /
 | |_| || |\  | |_| | |  | |/ ___ \|  _ <| |___|  _  | | |
  \____||_| \_|\___/|_|  |_/_/   \_\_| \_\\____|_| |_| |_|'

SPIN='|/-\'

ui_palette() {
  # Tokyo Night on the Linux console.
  printf '\e]P01a1b26\e]P1f7768e\e]P29ece6a\e]P3e0af68\e]P47aa2f7\e]P5bb9af7\e]P67dcfff\e]P7a9b1d6'
  printf '\e]P8414868\e]P9f7768e\e]PA9ece6a\e]PBe0af68\e]PC7aa2f7\e]PDbb9af7\e]PE7dcfff\e]PFc0caf5'
  printf '\e[0m'
}

ui_say() {
  if ((UNATTENDED)); then printf '%s\n' "$*"; else gum style --foreground 7 "$*"; fi
}

ui_warn() {
  if ((UNATTENDED)); then printf 'warning: %s\n' "$*"; else gum style --foreground 3 "$*"; fi
}

ui_header() {
  if ((UNATTENDED)); then
    printf '\n== %s ==\n' "$*"
    return
  fi
  clear
  gum style --foreground 6 --bold "$UI_BANNER"
  gum style --bold --margin "1 0" "$*"
}

installer_cancel() {
  ui_say "Installation cancelled. Nothing has been written to disk."
  exit 1
}

network_ok() { curl -sS -o /dev/null --max-time 8 https://archlinux.org/; }

# pacstrap needs the network. NetworkManager may still be bringing it up when
# the installer starts, so wait a minute before asking.
ensure_network() {
  local i choice
  for i in {1..12}; do
    network_ok && return 0
    ((UNATTENDED)) || gum spin --title "Waiting for the network..." -- sleep 5
    ((!UNATTENDED)) || sleep 5
  done
  ((!UNATTENDED)) || installer_abort "no network: pacstrap cannot download the base system"
  while :; do
    ui_header "No network connection"
    ui_say "Gnomarchy downloads the base system during installation. Connect a cable, or set up Wi-Fi."
    choice="$(gum choose "Retry" "Configure Wi-Fi" "Exit")" || installer_cancel
    case "$choice" in
      Retry) network_ok && return 0 ;;
      "Configure Wi-Fi")
        ui_say "In iwctl: station wlan0 scan, station wlan0 get-networks, station wlan0 connect <name>, then exit."
        iwctl || ui_warn "iwctl exited with an error."
        ;;
      *) installer_cancel ;;
    esac
  done
}

choose_disk() {
  local lines choice dev bytes
  mapfile -t lines < <(disk_candidates)
  ((${#lines[@]})) || installer_abort "no disk to install onto was found"
  while :; do
    ui_header "Choose a disk"
    choice="$(printf '%s\n' "${lines[@]}" | awk -F'\t' '{ printf "%-16s %s\n", $1, $3 }' |
      gum choose --header "Install Gnomarchy onto which disk? Everything on it will be erased.")" ||
      installer_cancel
    dev="${choice%% *}"
    bytes="$(printf '%s\n' "${lines[@]}" | awk -F'\t' -v d="$dev" '$1 == d { print $2 }')"
    if ((bytes < INSTALLER_MIN_DISK_BYTES)); then
      ui_warn "$dev is smaller than the 20 GiB Gnomarchy needs."
      sleep 2
      continue
    fi
    DISK="$dev"
    return 0
  done
}

run_form() {
  local choice confirm

  # Keyboard first, and switch the console to it: the passwords below are
  # then typed in the layout they will be entered in.
  ui_header "Keyboard layout"
  choice="$(keymap_menu | gum filter --header "Keyboard layout" --placeholder "Type to search" \
    --value "${KB_LABEL:-English (US)}")" || installer_cancel
  KEYMAP_ID="$(keymap_id_from_menu "$choice")"
  keymap_load "$KEYMAP_ID"
  loadkeys "$KB_CONSOLE_KEYMAP"
  if [[ -n "$KB_CONSOLE_FONT" ]]; then setfont "$KB_CONSOLE_FONT"; fi

  ui_header "About you"
  FULLNAME="$(gum input --header "Full name (optional)" --value "${FULLNAME:-}")" || installer_cancel
  while :; do
    USERNAME="$(gum input --header "Username" --value "${USERNAME:-}")" || installer_cancel
    valid_username "$USERNAME" && break
    ui_warn "Lowercase letters, digits, - and _, starting with a letter or _, at most 32, not root."
  done
  while :; do
    PASSWORD="$(gum input --password --header "Password for $USERNAME")" || installer_cancel
    confirm="$(gum input --password --header "Repeat the password")" || installer_cancel
    [[ -n "$PASSWORD" && "$PASSWORD" == "$confirm" ]] && break
    ui_warn "The passwords are empty or do not match."
  done

  ui_header "This computer"
  while :; do
    TARGET_HOSTNAME="$(gum input --header "Computer name" --value "${TARGET_HOSTNAME:-gnomarchy}")" || installer_cancel
    valid_hostname "$TARGET_HOSTNAME" && break
    ui_warn "Letters, digits and inner hyphens, at most 63."
  done
  TIMEZONE="$(timedatectl list-timezones | gum filter --header "Timezone" --placeholder "Type to search" \
    --value "${TIMEZONE:-UTC}")" || installer_cancel

  ENCRYPT=n
  DISK_PASSWORD="$PASSWORD"
  if gum confirm --default=false "Encrypt the disk with LUKS?"; then
    ENCRYPT=y
    if ! gum confirm "Use the same password to unlock the disk?"; then
      while :; do
        DISK_PASSWORD="$(gum input --password --header "Disk password")" || installer_cancel
        confirm="$(gum input --password --header "Repeat the disk password")" || installer_cancel
        [[ -n "$DISK_PASSWORD" && "$DISK_PASSWORD" == "$confirm" ]] && break
        ui_warn "The passwords are empty or do not match."
      done
    fi
  fi
}

# Returns 0 to install, 1 to edit; exits on Exit.
confirm_summary() {
  local layout="BIOS boot 1 MiB, EFI 4 GiB, Btrfs on the rest" choice desc
  [[ "$ENCRYPT" == y ]] && layout+=" (LUKS2 encrypted)"
  desc="$(disk_candidates | awk -F'\t' -v d="$DISK" '$1 == d { print $3 }')"
  ui_header "Ready to install"
  gum style --border rounded --padding "1 2" \
    "Disk       $DISK  $desc" \
    "Layout     $layout" \
    "User       ${FULLNAME:+$FULLNAME, }$USERNAME" \
    "Computer   $TARGET_HOSTNAME" \
    "Timezone   $TIMEZONE" \
    "Keyboard   $KB_LABEL"
  gum style --foreground 1 --bold "All data on $DISK will be erased."
  choice="$(gum choose "Install" "Edit" "Exit")" || installer_cancel
  case "$choice" in
    Install) return 0 ;;
    Edit) return 1 ;;
    *) installer_cancel ;;
  esac
}

# The install.sh stage currently running, from its markers in the log.
ui_substage() {
  [[ "${STAGE_FNS[$1]}" == stage_desktop ]] || return 0
  awk '/STAGE START: / { s = $0 }
    END { if (s) { sub(/.*STAGE START: /, "", s); sub(/ =+$/, "", s); print "install.sh: " s } }' "$LOG"
}

# ui_progress FRAME — redraws the stage list in place.
ui_progress() {
  local frame="$1" i mark sub last cols
  cols="$(tput cols)"
  printf '\e[H'
  printf '\e[36m%s\e[0m\e[K\n\n' "$UI_BANNER"
  for i in "${!STAGE_TITLES[@]}"; do
    case "${STAGE_STATE[i]}" in
      done) mark=$'\e[32m[ OK ]\e[0m' ;;
      run) mark=$'\e[36m[ '"${SPIN:frame%4:1}${SPIN:(frame+2)%4:1}"$' ]\e[0m' ;;
      fail) mark=$'\e[31m[FAIL]\e[0m' ;;
      *) mark=$'\e[2m[    ]\e[0m' ;;
    esac
    printf ' %s %s\e[K\n' "$mark" "${STAGE_TITLES[i]}"
    if [[ "${STAGE_STATE[i]}" == run ]]; then
      sub="$(ui_substage "$i")"
      if [[ -n "$sub" ]]; then printf '        \e[2m%s\e[0m\e[K\n' "$sub"; fi
    fi
  done
  last="$(tail -n 1 "$LOG" | tr -d '\r' | sed 's/\x1b\[[0-9;]*[A-Za-z]//g')"
  printf '\n  \e[2m%s\e[0m\e[K\n\e[J' "${last:0:$((cols - 4))}"
}
