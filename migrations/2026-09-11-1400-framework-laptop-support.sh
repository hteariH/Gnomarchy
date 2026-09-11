#!/bin/bash
# Framework laptop support for machines installed before the hardware profile.
#
# Framework 16: the RGB keyboard is a QMK device on hidraw, root-only until a
# udev rule hands it to the seat.
# Framework 13 AMD: the internal microphones live under a card profile PipeWire
# does not select by default, so they record nothing until it is chosen.
set -eEo pipefail

[[ "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)" == "Framework" ]] || exit 0

MODEL="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo '')"
echo "Framework laptop detected ($MODEL)."

if [[ "$MODEL" == *"Laptop 16"* ]]; then
  RULE=/etc/udev/rules.d/50-framework16-qmk-hid.rules
  if [[ ! -f "$RULE" ]]; then
    echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0012", MODE="0660", TAG+="uaccess"' |
      sudo tee "$RULE" >/dev/null
    sudo udevadm control --reload-rules 2>/dev/null || true
    echo "  Keyboard RGB access granted."
  fi

  if ! command -v qmk_hid >/dev/null 2>&1; then
    for helper in paru yay; do
      command -v "$helper" >/dev/null 2>&1 || continue
      "$helper" -S --needed --noconfirm qmk-hid >/dev/null 2>&1 ||
        echo "  qmk-hid failed to build; RGB control unavailable."
      break
    done
  fi
fi

# Applied immediately when a session is present; otherwise first-run picks it
# up at the next login.
if [[ "$MODEL" == *"Laptop 13"* ]] && command -v pactl >/dev/null 2>&1; then
  card="$(pactl list cards 2>/dev/null | grep -B20 "Family 17h/19h" |
    grep "Name: " | awk '{print $2}' | head -1 || true)"
  if [[ -n "$card" ]]; then
    pactl set-card-profile "$card" "HiFi (Mic1, Mic2, Speaker)" 2>/dev/null &&
      echo "  Internal microphones enabled." ||
      echo "  Could not select the microphone profile; it will retry at next login."
  fi
fi

exit 0
