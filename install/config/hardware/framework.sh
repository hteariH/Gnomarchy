#!/bin/bash

# Framework Laptop support
#
# Ported from Omarchy's Framework handling. Two things the hardware needs that
# no distribution does for you:
#
#   Framework 16  the RGB keyboard is a QMK device reached over hidraw, which
#                 is root-only until a udev rule grants the seat access
#   Framework 13  the AMD model exposes its microphones only under a card
#                 profile PipeWire does not pick by default, so the internal
#                 mics are silent until it is selected (done at first login,
#                 where PipeWire is actually running)

is_framework() {
  [[ "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)" == "Framework" ]]
}

framework_model() {
  cat /sys/class/dmi/id/product_name 2>/dev/null || echo ""
}

if ! is_framework; then
  return 0 2>/dev/null || exit 0
fi

MODEL="$(framework_model)"
echo "Framework laptop detected ($MODEL)."

# --- Framework 16: RGB keyboard -------------------------------------------
if [[ "$MODEL" == *"Laptop 16"* ]]; then
  RULE=/etc/udev/rules.d/50-framework16-qmk-hid.rules
  if [[ ! -f "$RULE" ]]; then
    # 32ac:0012 is the Framework 16 keyboard module. TAG+="uaccess" hands it to
    # the logged-in seat, so RGB control does not need root.
    echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0012", MODE="0660", TAG+="uaccess"' |
      sudo tee "$RULE" >/dev/null
    sudo udevadm control --reload-rules 2>/dev/null || true
    echo "  Keyboard RGB access granted to the local seat"
  fi

  # qmk-hid drives the keyboard's RGB; AUR-only, so it needs a helper.
  if ! command -v qmk_hid >/dev/null 2>&1; then
    for helper in paru yay; do
      command -v "$helper" >/dev/null 2>&1 || continue
      echo "  Installing qmk-hid for keyboard RGB control..."
      "$helper" -S --needed --noconfirm qmk-hid >/dev/null 2>&1 ||
        echo "  Warning: qmk-hid failed to build; RGB control unavailable."
      break
    done
  fi
fi

# The Framework 13 microphone fix needs a running PipeWire, so it is applied
# from the session rather than here. See install/desktop/set-hardware-session.sh
