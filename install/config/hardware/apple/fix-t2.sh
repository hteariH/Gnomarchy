#!/bin/bash

# Apple T2 Mac hardware quirks detection and handling
if dmesg 2>/dev/null | grep -qi "Apple T2" || lspci 2>/dev/null | grep -qi "Apple.*T2"; then
  echo "Apple T2 Hardware detected. Applying T2 audio and keyboard configs..."
  # Blacklist conflicting modules if necessary
  sudo mkdir -p /etc/modprobe.d
  echo "options apple-bce" | sudo tee /etc/modprobe.d/apple-t2.conf >/dev/null
fi
