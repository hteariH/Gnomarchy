#!/bin/bash
# The installer's field rules and keyboard table, against Arch's real kbd,
# xkeyboard-config and tzdata.
set -u
cd "$(dirname "$0")/../.." || exit 1
# shellcheck source=iso/tests/lib/assert.sh
source iso/tests/lib/assert.sh
# shellcheck source=iso/installer/lib/form.sh
source iso/installer/lib/form.sh

long32="$(printf 'a%.0s' {1..32})"
for u in alice a_b x1 _svc "$long32"; do t_true "username '$u' accepted" valid_username "$u"; done
for u in root 1abc Alice "a b" "" "${long32}a" a.b; do t_false "username '$u' refused" valid_username "$u"; done

long63="$(printf 'h%.0s' {1..63})"
for h in gnomarchy citest-host a 1host "$long63"; do t_true "hostname '$h' accepted" valid_hostname "$h"; done
for h in -host host- "has space" dots.not "" "${long63}h"; do t_false "hostname '$h' refused" valid_hostname "$h"; done

for z in UTC Europe/Berlin America/Argentina/Buenos_Aires; do t_true "timezone $z accepted" valid_timezone "$z"; done
for z in Mars/Base ../../etc/passwd "Europe/Berlin "; do t_false "timezone '$z' refused" valid_timezone "$z"; done

t_false "an unknown layout id is refused" keymap_fields xx
keymap_load de
t_eq "de console keymap" "$KB_CONSOLE_KEYMAP" "de-latin1"
t_eq "de X11 layout" "$KB_XKB_LAYOUT" "de"
t_eq "de has no variant" "$KB_XKB_VARIANT" ""
t_eq "the menu line round-trips" "$(keymap_id_from_menu "$(keymap_menu | grep '^German  \[')")" "de"

# The plain-layer symbol of keycode 16 (Q on a US keyboard), from the compiled
# table, so included keymap files count.
plain_q() {
  loadkeys --mktable --quiet "$1" | awk '
    /plain_map\[NR_KEYS\]/ { on = 1; next }
    on && /};/ { exit }
    on { gsub(/[{},]/, " "); for (i = 1; i <= NF; i++) v[n++] = $i }
    END { print v[16] }'
}

evdev=/usr/share/X11/xkb/rules/evdev.lst
layouts="$(awk '/^! layout/ { s = 1; next } /^!/ { s = 0 } s { print $1 }' "$evdev")"
variants="$(awk '/^! variant/ { s = 1; next } /^!/ { s = 0 } s { sub(":", "", $2); print $2 "/" $1 }' "$evdev")"

while IFS=$'\t' read -r id layout variant keymap font latin label extra; do
  [[ "$id" == \#* || -z "$id" ]] && continue
  if [[ -z "$label" || -n "$extra" ]]; then
    t_no "row $id does not have seven tab-separated fields"
    continue
  fi
  grep -qx "$layout" <<<"$layouts" && t_ok "$id: X11 layout $layout exists" || t_no "$id: no X11 layout $layout"
  if [[ "$variant" != - ]]; then
    grep -qx "$layout/$variant" <<<"$variants" && t_ok "$id: variant $variant exists" || t_no "$id: no variant $layout/$variant"
  fi
  if [[ -z "$(find /usr/share/kbd/keymaps -name "$keymap.map.gz" -print -quit)" ]]; then
    t_no "$id: no console keymap $keymap"
  else
    q="$(plain_q "$keymap")"
    # 0xfb61..0xfb7a: KT_LETTER a..z. A Latin default layer is what makes a
    # LUKS passphrase typeable at boot.
    if [[ "$q" =~ ^0xfb(6[1-9a-f]|7[0-9a])$ ]]; then
      t_ok "$id: console keymap $keymap starts on a Latin layer"
    else
      t_no "$id: console keymap $keymap does not start on a Latin layer" "keycode 16 plain: $q"
    fi
  fi
  if [[ "$font" != - ]]; then
    ls /usr/share/kbd/consolefonts/"$font".* >/dev/null && t_ok "$id: font $font exists" || t_no "$id: no console font $font"
  fi
  [[ "$latin" == yes || "$latin" == no ]] || t_no "$id: latin must be yes or no"
done <iso/installer/lib/keymaps.tsv

echo "--- unattended answers"
answers() {
  (
    unset "${!GNOMARCHY_@}"
    for kv in "$@"; do export "${kv?}"; done
    installer_check_answers && declare -p GNOMARCHY_HOSTNAME GNOMARCHY_TIMEZONE GNOMARCHY_KEYMAP GNOMARCHY_ENCRYPT GNOMARCHY_DISK_PASSWORD
  ) 2>&1
}
out="$(answers GNOMARCHY_DISK=/dev/vda GNOMARCHY_USERNAME=citest GNOMARCHY_PASSWORD=pw)"
t_true "minimal answers pass" grep -q 'GNOMARCHY_HOSTNAME="gnomarchy"' <<<"$out"
t_true "timezone defaults to UTC" grep -q 'GNOMARCHY_TIMEZONE="UTC"' <<<"$out"
t_true "keymap defaults to us" grep -q 'GNOMARCHY_KEYMAP="us"' <<<"$out"
t_true "encryption defaults to n" grep -q 'GNOMARCHY_ENCRYPT="n"' <<<"$out"
t_true "the disk password defaults to the user's" grep -q 'GNOMARCHY_DISK_PASSWORD="pw"' <<<"$out"
out="$(answers GNOMARCHY_DISK=/dev/vda GNOMARCHY_USERNAME=citest GNOMARCHY_PASSWORD=pw GNOMARCHY_ENCRYPT=Y)"
t_true "Y is normalised to y" grep -q 'GNOMARCHY_ENCRYPT="y"' <<<"$out"
out="$(answers GNOMARCHY_USERNAME=Root GNOMARCHY_HOSTNAME=-x GNOMARCHY_KEYMAP=xx GNOMARCHY_ENCRYPT=maybe)"
for p in GNOMARCHY_DISK GNOMARCHY_USERNAME GNOMARCHY_PASSWORD GNOMARCHY_HOSTNAME GNOMARCHY_KEYMAP GNOMARCHY_ENCRYPT; do
  t_true "a bad $p is reported" grep -q "answers: $p" <<<"$out"
done

t_done
