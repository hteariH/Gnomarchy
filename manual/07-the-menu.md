# The Command Center

Press `Super + Alt + Space`.

The command center is one window with a sidebar and three pages: Menu,
Keybindings and Manual. It opens on whichever page you asked for, so
`Super + K` opens straight to Keybindings and `Super + Shift + K` opens
straight to this Manual page.

## The Menu page

One flat, searchable list of the same actions the old bash menu had, grouped
under six headings:

    Appearance   switch theme, with fuzzy search over all 22
    Web Apps     add, list or remove web apps
    Capture      region to Satty, region to file, whole screen
    Snapshots    create a rollback point, or list existing ones
    System       update, shortcuts, restart the shell, extensions
    Power        lock, suspend, log out, reboot, power off

Picking **Theme** opens a gallery of colour swatches read straight from each
theme's `alacritty.toml`. `Enter` applies whichever one is highlighted.

Everything in the menu is also a plain command, and the menu is a front end,
never the only way in:

```bash
gnomarchy menu
gnomarchy theme set nord
gnomarchy capture annotate
```

## The keyboard model

The whole window works without a mouse:

    Ctrl + 1 / 2 / 3    jump to Menu / Keybindings / Manual
    Up / Down           walk the list, even while typing in search
    / or Ctrl + F        focus the search entry
    Enter               activate the selected row
    ?                   open the keyboard shortcuts window
    Esc                 unwind one level

`/` and `?` only act as shortcuts when focus is *not* already inside a text
entry - otherwise they type a literal character, the way you would expect.

`Esc` closes one thing at a time rather than the whole window outright: first
a dialog if one is open, then a non-empty search (clearing it), then a
rendered Manual page (back to the search results), and only then the window
itself.

## How it works

`gnomarchy menu`, `gnomarchy keybindings` and `gnomarchy manual` all open this
same application on their own page. Each falls back to its old text-only path
when there is no graphical display or `gjs` is not installed, which keeps
piping, scripting and SSH sessions working exactly as before.
