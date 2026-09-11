# Neovim

Neovim is set up with LazyVim. First launch syncs plugins and takes a moment.

## Theming

Each Gnomarchy theme ships a Neovim colorscheme. `gnomarchy theme set` writes
two files:

    ~/.config/nvim/lua/plugins/theme.lua
    ~/.config/nvim/lua/plugins/gnomarchy-colorscheme.lua

Both are regenerated on every theme switch - do not edit them.

The second file matters: without it LazyVim applies its own default colorscheme
after the theme spec has run, and the theme switch is silently undone.

## Your own configuration

Everything else under `~/.config/nvim/` is yours. Add files to `lua/plugins/`
as you would with any LazyVim setup; only the two files above are managed.

If you already had a Neovim configuration when Gnomarchy was installed, it was
left untouched and no LazyVim bootstrap was written.

## The editor for quick edits

VS Code is the graphical default and what opens for text files from the file
manager. Neovim is what you get in a TTY or over SSH.

`$EDITOR` follows the same split: `code --wait` under a graphical session,
`nvim` without one. The `--wait` is not optional - without it git sees the
editor exit immediately and treats your commit message as empty.
