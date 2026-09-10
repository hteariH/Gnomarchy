#!/bin/bash

# Intel hardware acceleration detection
if lspci -k 2>/dev/null | grep -EA3 'VGA|3D' | grep -qi "Intel"; then
  echo "Intel Graphics detected. Ensuring Intel media drivers are available..."
  sudo pacman -S --noconfirm --needed intel-media-driver vulkan-intel 2>/dev/null || true
fi
