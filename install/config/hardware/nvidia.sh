#!/bin/bash

# Nvidia Wayland detection and power management
if lspci -k 2>/dev/null | grep -EA3 'VGA|3D' | grep -qi "NVIDIA"; then
  echo "Nvidia GPU detected. Configuring Wayland and power management parameters..."
  # Enable Nvidia systemd sleep/suspend services if driver is installed
  sudo systemctl enable nvidia-suspend.service 2>/dev/null || true
  sudo systemctl enable nvidia-hibernate.service 2>/dev/null || true
  sudo systemctl enable nvidia-resume.service 2>/dev/null || true
  
  # Ensure DRM kernel mode setting is set
  sudo mkdir -p /etc/modprobe.d
  echo "options nvidia-drm modeset=1 fbdev=1" | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null
fi
