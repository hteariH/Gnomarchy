#!/bin/bash
# Deploy the Alacritty / btop / Neovim configurations that the theme engine
# writes into. Before this, themed colors were written to files nothing loaded.
set -eEo pipefail

GNOMARCHY_PATH="${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}"
DEFAULTS="$GNOMARCHY_PATH/default"

deploy() {
  local src="$1" dest="$2"
  [[ -f "$src" ]] || return 0
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" ]] && ! cmp -s "$src" "$dest"; then
    [[ -f "$dest.gnomarchy-bak" ]] || cp -f "$dest" "$dest.gnomarchy-bak"
  fi
  cp -f "$src" "$dest"
}

deploy "$DEFAULTS/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
deploy "$DEFAULTS/btop/btop.conf" "$HOME/.config/btop/btop.conf"

# Only install the LazyVim bootstrap when the user has no Neovim config of
# their own; never overwrite someone's editor setup.
if [[ ! -e "$HOME/.config/nvim/init.lua" && ! -e "$HOME/.config/nvim/init.vim" ]]; then
  mkdir -p "$HOME/.config/nvim/lua/config" "$HOME/.config/nvim/lua/plugins"
  cp -f "$DEFAULTS/nvim/init.lua" "$HOME/.config/nvim/init.lua"
  cp -f "$DEFAULTS/nvim/lua/config/lazy.lua" "$HOME/.config/nvim/lua/config/lazy.lua"
fi
