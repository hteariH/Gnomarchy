# Themes

```bash
gnomarchy theme list
gnomarchy theme set tokyo-night
gnomarchy theme current
```

22 themes: 18 dark, 4 light. Switching is instant and applies everywhere.

## What one command changes

- GNOME dark/light mode and the Libadwaita accent colour
- GTK3 and GTK4 window colours, generated from the theme palette
- GNOME Terminal - all 16 ANSI colours, plus background and foreground
- Alacritty, if you use it as a secondary terminal
- Neovim, through a LazyVim colorscheme
- btop
- The wallpaper
- The GDM login screen, when it can be updated without a password prompt

## The themes

Tokyo Night, Catppuccin, Catppuccin Latte, Ethereal, Everforest, Flexoki Light,
Gruvbox, Hackerman, Kanagawa, Last Horizon, Lumon, Lupine, Matte Black, Miasma,
Nord, Osaka Jade, Retro 82, Ristretto, Rose Pine, Solitude, Vantablack, White.

## Where a theme lives

    ~/.local/share/gnomarchy/themes/<name>/
      alacritty.toml    the canonical 16-colour palette
      neovim.lua        a lazy.nvim plugin spec
      btop.theme
      accent.txt        one of GNOME's accent names
      light.mode        present only for light themes
      backgrounds/      the bundled SVG fallback

`alacritty.toml` is the source of truth for colour: GNOME Terminal and the GTK
CSS are both generated from it.

## Your own theme

Drop a directory with the same layout into
`~/.config/gnomarchy/themes/<name>/` and it appears in `theme list`. User
themes take precedence over bundled ones with the same name.

## Files the engine owns

Do not hand-edit these; they are rewritten on every theme switch:

    ~/.config/alacritty/colors.toml
    ~/.config/btop/themes/current.theme
    ~/.config/nvim/lua/plugins/theme.lua
    ~/.config/nvim/lua/plugins/gnomarchy-colorscheme.lua
    ~/.config/gtk-3.0/gnomarchy-theme.css
    ~/.config/gtk-4.0/gnomarchy-theme.css
