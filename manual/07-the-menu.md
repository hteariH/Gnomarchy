# The Command Center

Press `Super + Alt + Space`.

One searchable menu over the system layer, so you do not have to remember which
command does what.

    Theme         switch theme, with fuzzy search over all 22
    Keybindings   search what is bound right now
    Web App       add, list or remove web apps
    Capture       region to Satty, region to file, whole screen
    Snapshot      create a rollback point, or list existing ones
    System        update, shortcuts, restart the shell, extensions
    Power         lock, suspend, log out, reboot, power off

## How it works

The menu is `gum` running inside a terminal window. Launched from the
keybinding it re-execs itself into GNOME Terminal, because a keybinding has no
terminal attached.

Everything in it is also a command:

```bash
gnomarchy menu
gnomarchy theme set nord
gnomarchy capture annotate
```

The menu is a front end, never the only way in.
