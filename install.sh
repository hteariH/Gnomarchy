#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Define Gnomarchy locations
export GNOMARCHY_PATH="${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}"
export GNOMARCHY_INSTALL="$GNOMARCHY_PATH/install"
export GNOMARCHY_INSTALL_LOG_FILE="/var/log/gnomarchy-install.log"
export PATH="$GNOMARCHY_PATH/bin:$HOME/.local/bin:$PATH"

# Ensure all Gnomarchy scripts are executable
chmod +x "$GNOMARCHY_PATH/bin"/* 2>/dev/null || true

# Symlink gnomarchy CLI globally to /usr/local/bin for all users
sudo ln -sf "$GNOMARCHY_PATH/bin/gnomarchy" /usr/local/bin/gnomarchy 2>/dev/null || true
sudo chmod +x /usr/local/bin/gnomarchy 2>/dev/null || true

# Mirror everything into the install log.
#
# This block previously created only the log's directory and never wrote to it,
# so the file the error handler points at ("Review detailed log output in ...")
# was always empty and no installation failure could be diagnosed after the
# fact.
sudo mkdir -p "$(dirname "$GNOMARCHY_INSTALL_LOG_FILE")" 2>/dev/null || true
sudo touch "$GNOMARCHY_INSTALL_LOG_FILE" 2>/dev/null || true
sudo chmod 666 "$GNOMARCHY_INSTALL_LOG_FILE" 2>/dev/null || true

if [[ -w "$GNOMARCHY_INSTALL_LOG_FILE" ]]; then
  exec > >(tee -a "$GNOMARCHY_INSTALL_LOG_FILE") 2>&1
  echo "===== Gnomarchy install started $(date -Iseconds) ====="
  echo "===== chroot=${GNOMARCHY_CHROOT_INSTALL:-0} user=${USER:-?} path=$GNOMARCHY_PATH ====="
fi

# Run each stage with a marker either side, so a log always shows which stage
# failed rather than just ending.
export GNOMARCHY_STAGE=""
run_stage() {
  export GNOMARCHY_STAGE="$1"
  echo "===== STAGE START: $1 ====="
  source "$GNOMARCHY_INSTALL/$1/all.sh"
  echo "===== STAGE OK: $1 ====="
}

source "$GNOMARCHY_INSTALL/helpers/all.sh"

run_stage preflight
run_stage packaging
run_stage config
run_stage desktop
run_stage login
run_stage post-install

echo "===== Gnomarchy install finished $(date -Iseconds) ====="
