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
