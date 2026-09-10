#!/bin/bash

# Ensure log destination is writable
if sudo -n true 2>/dev/null; then
  sudo touch "$GNOMARCHY_INSTALL_LOG_FILE" 2>/dev/null || true
  sudo chmod 666 "$GNOMARCHY_INSTALL_LOG_FILE" 2>/dev/null || true
fi

log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$GNOMARCHY_INSTALL_LOG_FILE" 2>/dev/null || true
}
