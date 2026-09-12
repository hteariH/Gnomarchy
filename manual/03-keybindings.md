# Keybindings

## Seeing what is bound

```bash
gnomarchy keybindings
gnomarchy keybindings --list
```

With no arguments this opens the command center's Keybindings page; `--list`
stays plain text, for grepping and for SSH. Either way it reads every binding
through typed `Gio.Settings`, so it always shows what is actually in effect -
including your keymap profile and whether dynamic tiling is on. It cannot go
stale.

## Rebinding a shortcut

`Enter` on a row in the Keybindings page opens a capture dialog: press the
combination you want, or type it, and it is saved. `Backspace` unbinds the
row instead, and `Esc` cancels without changing anything.

If the combination you pressed is already used elsewhere, a conflict dialog
names the action that currently holds it and offers **Replace** or **Cancel**
rather than silently taking it over.

**Reset to layout defaults**, at the bottom of the page, re-applies the
machine's recorded keymap profile by running `gnomarchy-keybindings reset`
underneath - so `bin/gnomarchy-keymap` stays the one place the defaults for
`gnome` and `omarchy` below are defined, rather than a copy living in the GUI
too.

Rebinding only changes an existing shortcut; it cannot create a new custom
slot. GNOME Settings already does that.

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
    Super + T                 cycle the zone layout (Tiling Shell)

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

## Super + digits belong to the workspaces

GNOME binds `switch-to-application-1` to `Super + 1` and so on up to
`Super + 9`: press one and it focuses, or launches, the Nth pinned app in the
dock. Gnomarchy puts the workspaces on those same keys, so each of them used to
have two handlers and did whichever the shell registered last.

The workspaces win, because that is what both profiles advertise:

| profile | workspaces | still switches applications |
|---|---|---|
| Gnomarchy defaults | `Super + 1..6` | `Super + 7`, `8`, `9` |
| Omarchy | `Super + 1..0` (ten) | nothing — all nine are workspaces |

Switching back from the Omarchy profile hands `Super + 7..9` to the
application switcher again. `gnomarchy keybindings` reads dconf, so it always
lists what is really bound.

## One deliberate difference from Omarchy

Omarchy puts its menu on `Super + Space`. In GNOME that switches the keyboard
layout, which most people use far more often than a launcher. So `Super + Space`
stays with the layout switcher and the menu keeps `Super + Alt + Space` in both
profiles.

## What could not be carried over

Hyprland features with no GNOME equivalent: window groups, the scratchpad,
pseudo-tiling, pixel-step window resize, moving a workspace between monitors.
`gnomarchy keymap status` lists them rather than pretending they exist.

## Dynamic tiling borrows two keys

`gnomarchy tiling enable` needs `K` and `Shift+K` for Forge's `hjkl`
navigation, so while dynamic tiling is on the keybindings browser moves to
`Super + /` and the manual to `Super + Shift + /`. `gnomarchy tiling disable`
moves them back, and `gnomarchy keybindings` reads dconf, so it always shows
whichever is really bound.
