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

# Ensure executable permissions and global PATH availability
chmod +x "$HOME/.local/share/gnomarchy/bin"/* 2>/dev/null || true
sudo ln -sf "$HOME/.local/share/gnomarchy/bin/gnomarchy" /usr/local/bin/gnomarchy 2>/dev/null || true
sudo chmod +x /usr/local/bin/gnomarchy 2>/dev/null || true

# System-wide profile hook
if [ -d /etc/profile.d ]; then
  sudo tee /etc/profile.d/gnomarchy.sh >/dev/null <<'PROFILE_EOF'
if [ -d "$HOME/.local/share/gnomarchy/bin" ]; then
  case ":$PATH:" in
    *:"$HOME/.local/share/gnomarchy/bin":*) ;;
    *) export PATH="$HOME/.local/share/gnomarchy/bin:$PATH" ;;
  esac
fi
PROFILE_EOF
fi
