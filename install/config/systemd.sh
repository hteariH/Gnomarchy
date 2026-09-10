#!/bin/bash

gnomarchy_header "Configuring Fast Shutdown & Systemd Timeouts"

# Ensure instant shutdown without waiting for hanging 90s processes
SYSTEMD_SYS_DIR="/etc/systemd/system.conf.d"
SYSTEMD_USER_DIR="/etc/systemd/user.conf.d"

if [[ $EUID -eq 0 ]]; then
  mkdir -p "$SYSTEMD_SYS_DIR" "$SYSTEMD_USER_DIR"
  cat > "$SYSTEMD_SYS_DIR/10-gnomarchy-timeout.conf" <<'EOF'
[Manager]
DefaultTimeoutStopSec=10s
DefaultTimeoutAbortSec=10s
EOF

  cat > "$SYSTEMD_USER_DIR/10-gnomarchy-timeout.conf" <<'EOF'
[Manager]
DefaultTimeoutStopSec=10s
DefaultTimeoutAbortSec=10s
EOF
  gnomarchy_step "Systemd shutdown timeout reduced to 10s"
else
  # If running in rootless/user context, apply user manager setting
  mkdir -p "$HOME/.config/systemd/user.conf.d"
  cat > "$HOME/.config/systemd/user.conf.d/10-gnomarchy-timeout.conf" <<'EOF'
[Manager]
DefaultTimeoutStopSec=10s
DefaultTimeoutAbortSec=10s
EOF
  gnomarchy_step "User systemd shutdown timeout reduced to 10s"
fi

gnomarchy_header "Enabling System Services"

# Services whose packages ship in gnomarchy-base.packages but which Arch does
# not enable on install. Without these the corresponding features are inert.
enable_service() {
  local unit="$1"
  if systemctl list-unit-files 2>/dev/null | grep -q "^${unit}"; then
    sudo systemctl enable "$unit" >/dev/null 2>&1 || true
  fi
}

enable_service bluetooth.service
enable_service avahi-daemon.service
enable_service ufw.service
enable_service plocate-updatedb.timer

# ydotoold backs Voxtype's "type the transcription into the focused window"
# step; it needs the daemon plus a writable /dev/uinput.
if systemctl list-unit-files 2>/dev/null | grep -q '^ydotoold.service'; then
  sudo systemctl enable ydotoold.service >/dev/null 2>&1 || true
fi

if [[ ! -f /etc/udev/rules.d/99-gnomarchy-uinput.rules ]]; then
  echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"'     | sudo tee /etc/udev/rules.d/99-gnomarchy-uinput.rules >/dev/null
  sudo udevadm control --reload-rules >/dev/null 2>&1 || true
fi

sudo usermod -aG input "$USER" >/dev/null 2>&1 || true

gnomarchy_step "System services enabled"
