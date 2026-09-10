#!/bin/bash

# Ensure ~/.bashrc sources Gnomarchy configurations
BASHRC_SRC='[ -f "$HOME/.local/share/gnomarchy/default/bash/bashrc" ] && source "$HOME/.local/share/gnomarchy/default/bash/bashrc"'

if [ -f "$HOME/.bashrc" ]; then
  if ! grep -q "gnomarchy/default/bash/bashrc" "$HOME/.bashrc"; then
    echo -e "\n# Gnomarchy configuration\n$BASHRC_SRC" >> "$HOME/.bashrc"
  fi
else
  echo -e "# Gnomarchy configuration\n$BASHRC_SRC" > "$HOME/.bashrc"
fi
