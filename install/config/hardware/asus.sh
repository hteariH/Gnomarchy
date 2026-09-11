#!/bin/bash

# Asus laptop support (ROG and TUF)
#
# Both lines expose the same asus_wmi kernel interface, so one profile covers
# them: fan curves, platform profiles, keyboard backlight and a battery charge
# limit, through asusd.
#
# asusctl is in the extra repository, so no AUR build is needed. It declares no
# conflict with power-profiles-daemon and the two coexist: PPD drives the
# profile switcher GNOME shows, asusd handles the hardware GNOME cannot reach.

is_asus_laptop() {
  local vendor=""
  for f in /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/board_vendor; do
    [[ -r "$f" ]] && vendor+="$(<"$f") "
  done
  # Match the vendor string, not the model: "ASUSTeK COMPUTER INC." covers ROG,
  # TUF and the rest of the range.
  grep -qi 'asustek\|asus' <<<"$vendor"
}

if ! is_asus_laptop; then
  return 0 2>/dev/null || exit 0
fi

MODEL="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo 'unknown')"
echo "Asus laptop detected ($MODEL). Installing asusctl..."

# rog-control-center is the official GUI and ships in extra at the same
# version as asusctl. Despite the name it covers TUF as well.
if sudo pacman -S --noconfirm --needed asusctl rog-control-center 2>/dev/null; then
  # asusd owns the hardware; without it asusctl can only report.
  sudo systemctl enable asusd.service >/dev/null 2>&1 || true
  echo "  asusd enabled - fan curves, keyboard backlight and charge limit available"
  echo "  ROG Control Center installed (also in the app grid)"
else
  echo "  Warning: asusctl could not be installed; skipping Asus configuration."
  return 0 2>/dev/null || exit 0
fi

# supergfxctl switches between the integrated and discrete GPU without a
# reboot, which is worth a lot of battery on a hybrid laptop. It is AUR-only,
# so it is installed only when there is a discrete NVIDIA GPU to switch to and
# a helper to build it with.
if lspci 2>/dev/null | grep -iE 'vga|3d' | grep -qi nvidia; then
  for helper in paru yay; do
    if command -v "$helper" >/dev/null 2>&1; then
      echo "  Hybrid NVIDIA graphics detected; installing supergfxctl..."
      if "$helper" -S --needed --noconfirm supergfxctl >/dev/null 2>&1; then
        sudo systemctl enable supergfxd.service >/dev/null 2>&1 || true
        echo "  supergfxd enabled - switch with 'gnomarchy asus graphics'"
      else
        echo "  Warning: supergfxctl failed to build; graphics switching unavailable."
      fi
      break
    fi
  done
fi
