# Terminal

GNOME Terminal is the default. `Super + Return` opens one.

## Why GNOME Terminal

It integrates with GNOME properly and, unlike GNOME Console, it supports custom
colour palettes - which the theme engine needs in order to theme it.

## The Gnomarchy profile

The installer creates a profile with a fixed id so the theme engine always
knows which one to recolour:

- JetBrains Mono Nerd Font 10
- 110x30, no scrollbar, 10000 lines of scrollback
- `use-theme-colors` off, so the theme owns the colours

Colours live in dconf, not a config file. Do not set them by hand; a theme
switch will overwrite them.

## Shell

Bash with starship, zoxide and mise. Aliases live in
`~/.local/share/gnomarchy/default/bash/aliases`.

Note that `grep`, `find` and `cat` are deliberately not shadowed by ripgrep, fd
and bat. Scripts and muscle memory depend on their real flags. The modern tools
are available under their own names.
