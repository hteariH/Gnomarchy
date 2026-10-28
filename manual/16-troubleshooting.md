# Troubleshooting

## No keyboard shortcuts work

The desktop configuration is applied at first login, not during installation -
the installer runs in a chroot where dconf writes go nowhere.

```bash
gnomarchy first-run
```

Then log out and back in.

To see what happened on the last attempt:

```bash
journalctl --user -t gnomarchy-first-run
```

That trace names the step that failed. Nothing at all means the autostart entry
never ran; check that `~/.config/autostart/gnomarchy-first-run.desktop` exists
and does **not** contain `X-GNOME-Autostart-Phase`, which makes GNOME 50 and later skip
the entry entirely.

## An extension shows an error

Usually a missing compiled schema:

    GLib.FileError: Failed to open file ".../schemas/gschemas.compiled"

```bash
gnomarchy update
```

Or directly:

```bash
for d in ~/.local/share/gnome-shell/extensions/*/schemas; do
  [ -d "$d" ] && glib-compile-schemas "$d"
done
```

Log out and back in afterwards - extensions load only when the shell starts.

## Tiling does nothing

```bash
gnomarchy tiling status
```

`shell state` should read `ACTIVE`. Anything else means the shell refused the
extension -- usually a build that does not declare the running GNOME version.
`gnomarchy tiling enable` re-applies Gnomarchy's settings if they were changed
by hand.

## The wallpaper is a plain gradient

That is the bundled SVG fallback, which means the upstream wallpapers did not
download.

```bash
gnomarchy backgrounds
gnomarchy theme set "$(gnomarchy theme current)"
```

## gnomarchy update says nothing changed

Check that it is actually tracking a repository:

```bash
git -C ~/.local/share/gnomarchy status -sb
```

Machines installed from older ISOs were deployed without one. Recent versions
of `gnomarchy update` create it automatically.

## A command is not found from a keybinding

Every `gnomarchy-*` command must be in `/usr/local/bin` to be reachable from the
GNOME session, which does not read your shell profile.

```bash
ls /usr/local/bin/gnomarchy*
gnomarchy update
```

## Getting more detail

    /var/log/gnomarchy-installer.log      the installer, with the failing stage
    /var/log/gnomarchy-install.log        installation
    journalctl -b 0 /usr/bin/gnome-shell  the current session's shell
    gnomarchy version --verbose           version, theme, migrations applied
