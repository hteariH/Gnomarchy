#!/bin/bash
# Voxtype shipped without a speech-to-text backend or a running ydotool
# daemon, so Super+D could never transcribe or type. Install both.
set -eEo pipefail

sudo pacman -S --noconfirm --needed whisper-cpp ydotool 2>/dev/null || true

# ydotool needs its daemon running and /dev/uinput writable by the input group.
if systemctl list-unit-files 2>/dev/null | grep -q '^ydotoold.service'; then
  sudo systemctl enable --now ydotoold.service 2>/dev/null || true
fi

if [[ ! -f /etc/udev/rules.d/99-gnomarchy-uinput.rules ]]; then
  echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' \
    | sudo tee /etc/udev/rules.d/99-gnomarchy-uinput.rules >/dev/null
  sudo udevadm control --reload-rules 2>/dev/null || true
fi

sudo usermod -aG input "$USER" 2>/dev/null || true
