# Tiling

Gnomarchy ships two window management models and lets you pick.

```bash
gnomarchy tiling status
gnomarchy tiling enable
gnomarchy tiling disable
```

Only one runs at a time. Enabled together they fight over window placement.

## Manual: Tactile (default)

Press `Super + T`. A grid overlay appears; press the letter for the zone you
want. Nothing moves unless you move it.

Good if you like a predictable desktop and only occasionally want windows
snapped into place.

## Dynamic: Tiling Shell

New windows are placed into the layout automatically and neighbours resize to
fit - the Hyprland model.

    Super + h/j/k/l           focus (Gnomarchy layout)
    Super + Shift + h/j/k/l   move
    Super + arrows            focus (Omarchy layout)
    Super + Shift + arrows    move
    Super + Shift + C         centre window

Pair it with the Omarchy keymap for the full effect:

```bash
gnomarchy keymap omarchy && gnomarchy tiling enable
```

Log out and back in - under Wayland the shell cannot reload in place.

## Honest limitations

This is an extension on top of Mutter, not a tiling compositor. It does not
have Hyprland's dwindle and master layouts, window groups, or a scratchpad.
It tiles automatically and stays out of your way; it is not a reimplementation
of Hyprland.

## Why not Forge or Pop Shell

Forge supports GNOME up to 49 and Gnomarchy runs 50. Pop Shell is not published
on extensions.gnome.org and its GNOME 45+ support is community-maintained.
Tiling Shell declares support through 50.
