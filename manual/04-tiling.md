# Tiling

Tiling is Tiling Shell, configured so that nothing moves unless you move it.

```bash
gnomarchy tiling status
gnomarchy tiling enable
gnomarchy tiling disable
```

It is on by default. `disable` turns it off and leaves windows as stock GNOME
handles them; `enable` turns it back on and re-applies Gnomarchy's settings.

## Keys

    Ctrl + drag               pick a zone for the window you are dragging
    drag to the top edge      snap assist
    Super + Shift + arrows    throw the window into the next tile
    Super + Shift + U         untile, back to the window's original size
    Super + T                 cycle which zone layout is active

Tiling Shell's own preferences have a layout editor if the built-in zone
layouts do not suit you.

## Auto-placement is off

Its `enable-autotiling` setting is deliberately **off** here. With it on,
Tiling Shell drops each new window into a free tile of the current layout and
does not touch the windows already on screen — the first window lands in the
wide centre tile, the second in a narrow side tile, and the first one does not
move. That is not what most people mean by automatic tiling, so Gnomarchy does
not pretend to offer it.

## A key that moved

Tiling Shell throws windows with `Super + Shift + arrows`, which is GNOME's
default for moving a window to the next monitor. Two handlers on one key is a
coin toss, so that one moves:

| | GNOME default | on Gnomarchy |
|---|---|---|
| move window to the next monitor | `Super + Shift + arrows` | `Super + Ctrl + Shift + arrows` |

`gnomarchy keybindings` reads dconf, so it always shows what is really bound.

## Honest limitations

This is an extension on top of Mutter, not a tiling compositor. There is no
tree tiling where windows resize to make room, no directional focus, and none
of Hyprland's window groups, scratchpad or per-monitor workspace moves.
`gnomarchy keymap status` lists what was left out rather than pretending
otherwise.

`gnomarchy tiling status` prints the shell's own view of the extension, so a
build that does not load shows up as something other than `ACTIVE` rather
than as tiling that quietly does nothing.
