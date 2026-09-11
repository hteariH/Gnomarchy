#!/bin/bash
# Install Asus laptop support on machines that predate the hardware profile.
#
# ROG and TUF share the asus_wmi interface, so one profile covers both. asusctl
# is in the extra repository and declares no conflict with
# power-profiles-daemon; the two coexist.
set -eEo pipefail

vendor=""
for f in /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/board_vendor; do
  [[ -r "$f" ]] && vendor+="$(<"$f") "
done

grep -qi 'asustek\|asus' <<<"$vendor" || exit 0

echo "Asus laptop detected ($(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown))."

# rog-control-center is the official GUI, in extra at the same version.
sudo pacman -S --noconfirm --needed asusctl rog-control-center 2>/dev/null ||
  { echo "  Could not install asusctl."; exit 0; }

sudo systemctl enable --now asusd.service 2>/dev/null || true
echo "  asusd enabled."

# Only worth building supergfxctl where there is a discrete GPU to switch to.
if lspci 2>/dev/null | grep -iE 'vga|3d' | grep -qi nvidia; then
  if ! command -v supergfxctl >/dev/null 2>&1; then
    for helper in paru yay; do
      command -v "$helper" >/dev/null 2>&1 || continue
      echo "  Building supergfxctl from the AUR..."
      "$helper" -S --needed --noconfirm supergfxctl >/dev/null 2>&1 &&
        sudo systemctl enable --now supergfxd.service 2>/dev/null || true
      break
    done
  fi
fi

echo "  Try: gnomarchy asus status"
exit 0
