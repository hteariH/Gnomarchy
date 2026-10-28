# Getting Started

## Installing

Boot the ISO; the installer starts on its own on the first console.

1. **Disk.** Choose the disk. All of it is used and erased; disks under
   20 GiB are refused.
2. **Form.** Keyboard layout first — the console switches to it, so the
   passwords that follow are typed the way you will type them later. Then
   your name, user name, password, the computer's name and the timezone (type
   to search). Encryption is optional; the disk password can be the same as
   your own.
3. **Summary.** Check it. *Edit* goes back to the form with your answers
   kept; nothing is written until you choose *Install*.
4. **Progress.** Seven stages. If one fails, the screen shows the end of the
   log and offers the full log, a shell, or power off. The log is
   `/var/log/gnomarchy-installer.log`, copied to the installed system.

## The first five minutes

Press `Super + Alt + Space`. That is the command center: themes, web apps,
screen capture, snapshots, updates and power, all in one searchable menu.

Press `Super + K` for the keybindings, read out of your live configuration
rather than a list somebody wrote once.

Press `Super + Return` for a terminal.

## Making it yours

```bash
gnomarchy theme list
gnomarchy theme set kanagawa
```

A theme changes the GNOME accent and dark/light mode, GTK window colours, the
terminal palette, Neovim, btop and the wallpaper - in one command.

## If you came from Omarchy

Your muscle memory can come with you:

```bash
gnomarchy keymap omarchy
```

See `gnomarchy manual 03` for what it binds and `04` for tiling.

## If you came from stock GNOME

Everything you know still works. The additions are the command center, the
theme engine and the `gnomarchy` CLI. Nothing removes GNOME behaviour.
