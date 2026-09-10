#!/bin/bash

gnomarchy_header "Setting up Gnomarchy Lifecycle Event Hooks"

HOOKS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gnomarchy/hooks"
SAMPLES_DIR="$HOOKS_DIR/samples"

mkdir -p "$SAMPLES_DIR"

HOOKS_SOURCE="$GNOMARCHY_PATH/default/hooks"
if [[ ! -d "$HOOKS_SOURCE" ]]; then
  HOOKS_SOURCE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../default/hooks" && pwd)"
fi

if [[ -d "$HOOKS_SOURCE" ]]; then
  cp "$HOOKS_SOURCE"/*.sample "$SAMPLES_DIR/" 2>/dev/null || true
  chmod 755 "$SAMPLES_DIR"/*.sample 2>/dev/null || true
fi

gnomarchy_step "Event hooks initialized in $HOOKS_DIR"
