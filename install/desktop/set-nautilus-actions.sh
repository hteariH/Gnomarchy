#!/bin/bash

gnomarchy_header "Configuring Nautilus Context Menu Extensions"

EXT_DIR="/usr/share/nautilus-python/extensions"
USER_EXT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nautilus-python/extensions"

SOURCE_EXT="$GNOMARCHY_PATH/default/nautilus/gnomarchy_actions.py"
if [[ ! -f "$SOURCE_EXT" ]]; then
  SOURCE_EXT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../default/nautilus" && pwd)/gnomarchy_actions.py"
fi

if [[ -f "$SOURCE_EXT" ]]; then
  # System-wide installation if root, otherwise user local
  if [[ $EUID -eq 0 ]]; then
    mkdir -p "$EXT_DIR"
    cp "$SOURCE_EXT" "$EXT_DIR/gnomarchy_actions.py"
    chmod 644 "$EXT_DIR/gnomarchy_actions.py"
  else
    mkdir -p "$USER_EXT_DIR"
    cp "$SOURCE_EXT" "$USER_EXT_DIR/gnomarchy_actions.py"
    chmod 644 "$USER_EXT_DIR/gnomarchy_actions.py"
  fi
  gnomarchy_step "Nautilus media & utility context actions installed"
else
  echo "Warning: $SOURCE_EXT not found."
fi
