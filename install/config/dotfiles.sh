#!/bin/bash

gnomarchy_header "Deploying Developer Tool Configurations"

# Copy a shipped default into place without ever clobbering a config the user
# has already customised. Existing files are backed up once, so re-running the
# installer is safe.
deploy_config() {
  local src="$1"
  local dest="$2"

  [[ -f "$src" ]] || return 0
  mkdir -p "$(dirname "$dest")"

  if [[ -f "$dest" ]]; then
    if cmp -s "$src" "$dest"; then
      return 0
    fi
    if [[ ! -f "$dest.gnomarchy-bak" ]]; then
      cp -f "$dest" "$dest.gnomarchy-bak"
      echo "  Backed up existing $(basename "$dest") -> $(basename "$dest").gnomarchy-bak"
    fi
  fi

  cp -f "$src" "$dest"
  echo "  Installed $(basename "$dest")"
}

DEFAULTS="$GNOMARCHY_PATH/default"

# 1. Alacritty: font, padding and opacity. Colors come from the theme engine,
#    which writes colors.toml alongside this file.
deploy_config "$DEFAULTS/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"

# 2. btop: selects the "current" theme that `gnomarchy theme set` rewrites.
deploy_config "$DEFAULTS/btop/btop.conf" "$HOME/.config/btop/btop.conf"

# 3. Neovim: LazyVim bootstrap. Without this the per-theme neovim.lua plugin
#    specs have nothing to load them.
if [[ -d "$DEFAULTS/nvim" ]]; then
  if [[ -f "$HOME/.config/nvim/init.lua" ]] && ! grep -q "config.lazy" "$HOME/.config/nvim/init.lua" 2>/dev/null; then
    echo "  Existing Neovim config detected - leaving it untouched."
  else
    mkdir -p "$HOME/.config/nvim/lua/plugins"
    cp -f "$DEFAULTS/nvim/init.lua" "$HOME/.config/nvim/init.lua"
    mkdir -p "$HOME/.config/nvim/lua/config"
    cp -f "$DEFAULTS/nvim/lua/config/lazy.lua" "$HOME/.config/nvim/lua/config/lazy.lua"
    echo "  Installed LazyVim bootstrap (plugins sync on first nvim launch)"
  fi
fi

gnomarchy_step "Developer tool configurations deployed"
