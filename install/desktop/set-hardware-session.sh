#!/bin/bash

gnomarchy_header "Applying Session Hardware Fixes"

# Hardware tweaks that need a running user session rather than a chroot:
# anything talking to PipeWire, dconf or the seat. Run from
# gnomarchy-first-run, which has all three.

# --- Framework 13 AMD: silent internal microphones -------------------------
#
# The AMD model exposes its two internal mics only under a specific card
# profile. PipeWire picks a different one by default, so the mics appear
# present and record nothing until this is selected.
if [[ "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)" == "Framework" ]] &&
  [[ "$(cat /sys/class/dmi/id/product_name 2>/dev/null)" == *"Laptop 13"* ]] &&
  command -v pactl >/dev/null 2>&1; then

  amd_card="$(pactl list cards 2>/dev/null | grep -B20 "Family 17h/19h" |
    grep "Name: " | awk '{print $2}' | head -1 || true)"

  if [[ -n "$amd_card" ]]; then
    target="HiFi (Mic1, Mic2, Speaker)"
    if pactl set-card-profile "$amd_card" "$target" 2>/dev/null; then
      gnomarchy_step "Framework 13 microphones enabled"
    else
      gnomarchy_warn "Could not select the Framework 13 microphone profile"
    fi
  fi
fi

gnomarchy_step "Session hardware fixes applied"
