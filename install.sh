#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Define Gnomarchy locations
export GNOMARCHY_PATH="${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}"
export GNOMARCHY_INSTALL="$GNOMARCHY_PATH/install"
export GNOMARCHY_INSTALL_LOG_FILE="/var/log/gnomarchy-install.log"
export PATH="$GNOMARCHY_PATH/bin:$PATH"

# Log everything to install log file while showing output on terminal
mkdir -p "$(dirname "$GNOMARCHY_INSTALL_LOG_FILE")" 2>/dev/null || true

# Source installer stages in ordered progression
source "$GNOMARCHY_INSTALL/helpers/all.sh"
source "$GNOMARCHY_INSTALL/preflight/all.sh"
source "$GNOMARCHY_INSTALL/packaging/all.sh"
source "$GNOMARCHY_INSTALL/config/all.sh"
source "$GNOMARCHY_INSTALL/desktop/all.sh"
source "$GNOMARCHY_INSTALL/login/all.sh"
source "$GNOMARCHY_INSTALL/post-install/all.sh"
