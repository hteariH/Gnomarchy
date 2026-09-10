# Welcome to Gnomarchy

Gnomarchy is Omarchy's tooling and Arch base with a tuned GNOME desktop instead
of Hyprland. Same rolling release, same Btrfs snapshots, same opinionated
developer stack - a different window manager underneath.

## What that means in practice

You get GNOME's polish and hardware handling: Wayland that works, fractional
scaling, a settings app, portals that behave. On top of that sits the Omarchy
layer - a unified theme engine, a command center, web apps, dictation, atomic
rollbacks.

## What is different from Omarchy

GNOME is not Hyprland, and some things do not translate:

- Window groups, the scratchpad and pseudo-tiling have no GNOME equivalent.
- Dynamic tiling is opt-in and provided by an extension, not the compositor.
- Configuration lives in dconf, not a text file you edit.

Where a feature could not be carried across, it is named rather than quietly
dropped. See `gnomarchy keymap status`.

## Where to go next

- `gnomarchy manual 02` - getting started
- `gnomarchy manual 03` - keybindings
- `gnomarchy keybindings` - what is bound right now
