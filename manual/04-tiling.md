# Tiling

Gnomarchy ships two window management models and lets you pick.

```bash
gnomarchy tiling status
gnomarchy tiling enable
gnomarchy tiling disable
```

Only one runs at a time. Enabled together they fight over placement.

## Manual: Tiling Shell (default)

Zones you choose, applied when you say so. Nothing moves on its own.

    Ctrl + drag               pick a zone for the window you are dragging
    drag to the top edge      snap assist
    Super + Shift + arrows    throw the window into the next tile
    Super + Shift + U         untile, back to the window's original size
    Super + T                 cycle which zone layout is active

Tiling Shell's own preferences have a layout editor if the built-in zone
layouts do not suit you.

Its `enable-autotiling` setting is deliberately **off** here. With it on,
Tiling Shell drops each new window into a free tile of the current layout and
does not touch the windows already on screen — the first window lands in the
wide centre tile, the second in a narrow side tile, and the first one does not
move. That is not what most people mean by automatic tiling, and it is why
dynamic mode is a different extension entirely.

## Dynamic: Forge

Windows are tiled into a binary tree. Opening a window splits the focused one
and **both halves resize**. Closing a window gives its space back to its
sibling. Nothing overlaps, nothing is left floating. This is the Hyprland
model, and it is the thing Tiling Shell cannot do.

    Super + h/j/k/l           focus left/down/up/right
    Super + Shift + h/j/k/l   move the window within the tree
    Super + Ctrl + h/j/k/l    swap the window with its neighbour
    Super + C                 float the focused window
    Super + G                 flip the split direction
    Super + Z / Super + V     force the next split horizontal / vertical
    Super + [ / Super + ]     shrink / expand the focused window
    Super + =                 reset every window to an even split
    Super + Shift + S / T     stacked / tabbed layout for this container
    Super + Alt + T           suspend tiling without disabling the extension

Pair it with the Omarchy keymap, which moves focus and movement onto the
arrows and keeps hjkl as an alternate:

```bash
gnomarchy keymap omarchy && gnomarchy tiling enable
```

Log out and back in — under Wayland the shell cannot reload in place.

### Keys that move to make room

A tiling extension and GNOME want the same accelerators. Two handlers on one
key is a coin toss, so each conflict is resolved rather than left to chance.

**In both modes**, because both throw windows with `Super + Shift + arrows`:

| | GNOME default | on Gnomarchy |
|---|---|---|
| move window to the next monitor | `Super + Shift + arrows` | `Super + Ctrl + Shift + arrows` |

**In dynamic mode only**, because Forge needs `h`, `v`, `k` and `Shift+K`:

| | manual mode | dynamic mode |
|---|---|---|
| keybindings browser | `Super + K` | `Super + /` |
| the manual | `Super + Shift + K` | `Super + Shift + /` |
| notification list | `Super + V` or `Super + M` | `Super + M` |
| minimize window | `Super + H` | unbound |

`gnomarchy tiling disable` puts all four back. `gnomarchy keybindings` always
reads dconf, so it shows whichever is actually bound.

On the Omarchy keymap, `Super + Down` is directional focus, so `unmaximize`
keeps only its other default, `Alt + F5`.

Dynamic mode also turns `org.gnome.mutter auto-maximize` off. A window that
opens maximized is not part of the tree, and Mutter maximizes anything large
enough by default, so the first window of a session used to escape tiling
entirely. `gnomarchy tiling disable` resets it.

## Honest limitations

This is an extension on top of Mutter, not a tiling compositor. Forge gives
you the tree, splits, stacked and tabbed containers, and keyboard resize. It
does not give you Hyprland's window groups, scratchpad, or per-monitor
workspace moves. `gnomarchy keymap status` lists what was left out rather than
pretending otherwise.

## Where Forge comes from

The bundled build is <https://github.com/jcrussell/forge>, not the Forge on
extensions.gnome.org. That one is `forge-ext/forge`, whose own metadata stops
at GNOME 49 and whose description asks for a new maintainer; Gnomarchy runs
GNOME 50, and that build would install and then never load. The fork is
maintained and declares 50.

`gnomarchy tiling status` prints the shell's own view of the extension state,
so an incompatible build shows up as something other than `ACTIVE` rather than
as tiling that quietly does nothing.

## What happened to Tactile

Tactile was the manual mode until Tiling Shell replaced it. Manual-mode Tiling
Shell does everything Tactile did — a grid of zones you pick — and adds snap
assist, a layout editor and multi-monitor handling. Keeping both meant two
extensions competing for the same job. `Super + T` still does something in
manual mode: it cycles the active zone layout.
