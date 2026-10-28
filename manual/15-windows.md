# Windows apps

```bash
gnomarchy windows install
gnomarchy windows status
gnomarchy windows
```

Windows applications through [WinBoat](https://www.winboat.app). WinBoat runs
Windows in a Docker container and opens its applications as ordinary windows on
your desktop, over FreeRDP. Nothing is installed until you ask for it.

## Installing

`gnomarchy windows install` installs `winboat-bin` from the AUR with paru. If
that fails, it downloads the WinBoat release AppImage instead, checks it against
the checksum published with the release, and adds a WinBoat entry to the app
grid. Either way it starts Docker if it is not running.

The first start of WinBoat downloads Windows and creates the container. That
takes a while, and several GB of disk.

## What you need

- A CPU with virtualisation (VT-x or AMD-V) enabled in firmware: `/dev/kvm`
- Docker running, and your user in the `docker` group. Gnomarchy sets both up
  at install time; the group takes effect from your next login.
- FreeRDP, which WinBoat drives. It comes with either install path.
- Memory to spare: Windows in the container wants several GB.

`gnomarchy windows status` checks each of these and says which one is missing.

## Notes

For a single Windows application, try a web app or a Wine prefix first - a
whole Windows is a lot of machinery for one program.

Gnomarchy used to create a QEMU virtual machine here. If you made one, it is
still in `~/.local/share/gnomarchy/vms/windows-11`; nothing deletes it, and
`gnomarchy windows status` mentions it.
