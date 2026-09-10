# Keybindings

## Seeing what is bound

```bash
gnomarchy keybindings
gnomarchy keybindings --list
```

This reads dconf, so it always shows what is actually in effect - including
your keymap profile and whether dynamic tiling is on. It cannot go stale.

## Two profiles

```bash
gnomarchy keymap gnome
gnomarchy keymap omarchy
gnomarchy keymap status
```

### Gnomarchy defaults

    Super + Return            terminal
    Super + B                 browser
    Super + E                 files
    Super + Alt + Space       command center
    Super + K                 keybindings
    Super + W                 close window
    Super + Up                maximize
    Super + 1..6              workspaces
    Super + T                 Tactile grid

### Omarchy profile

    Super + Return            terminal
    Super + Shift + B         browser
    Super + Shift + F         files
    Super + Shift + N         editor
    Super + W / Super + Q     close window
    Super + F                 fullscreen
    Super + Alt + F           maximize
    Super + arrows            focus window
    Super + Shift + arrows    move window
    Super + 1..0              ten workspaces
    Super + Tab               next workspace
    Super + drag              move window
    Super + right-drag        resize window

## One deliberate difference from Omarchy

Omarchy puts its menu on `Super + Space`. In GNOME that switches the keyboard
layout, which most people use far more often than a launcher. So `Super + Space`
stays with the layout switcher and the menu keeps `Super + Alt + Space` in both
profiles.

## What could not be carried over

Hyprland features with no GNOME equivalent: window groups, the scratchpad,
pseudo-tiling, pixel-step window resize, moving a workspace between monitors.
`gnomarchy keymap status` lists them rather than pretending they exist.
