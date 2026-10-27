# Where the bundled extensions come from

Every zip in this directory is installed by `install/desktop/install-extensions.py`
during the chroot stage, before any session exists. Most of them are the
published extensions.gnome.org builds and can be refreshed from there.

One cannot, and that is the reason this file exists.

## forge@jmmaranan.com

| | |
|---|---|
| source | <https://github.com/jcrussell/forge> (fork of `forge-ext/forge`) |
| release | `v49-90-beta.4`, published 2026-10-25 |
| version-name | `v49-90-beta.4` |
| shell-version | 45, 46, 47, 48, 49, 50, **51** |
| sha256 | `737b424e25e7a5447ff0e338ba93e7080366b305edf496b1272203d55195c4b8` |

**Do not refresh this one from extensions.gnome.org.** The Forge listed there
is `forge-ext/forge`, which stops at GNOME 49 — its own `metadata.json` says
so, and upstream's description reads "Needs a new maintainer". Installing that
build on Gnomarchy's GNOME 51 gives an extension the shell refuses to load.
The fork above is maintained, declares 51, and is what `gnomarchy tiling
enable` expects.

The zip already contains `schemas/gschemas.compiled`, so it loads even if the
compile step in `install-extensions.py` is skipped.

To refresh it:

```bash
tag=v49-90-beta.4   # or the newer tag you are moving to
base="https://github.com/jcrussell/forge/releases/download/$tag"
curl -fsSL -o "forge@jmmaranan.com.zip" "$base/forge%40jmmaranan.com.zip"
curl -fsSL "$base/SHA256SUMS"
sha256sum "forge@jmmaranan.com.zip"      # must match SHA256SUMS
unzip -p "forge@jmmaranan.com.zip" metadata.json | grep shell-version
```

The last line is not optional: a build that does not list `"51"` must not be
committed. Update the table above in the same commit, and update the pinned
URL and checksum in `install/desktop/install-extensions.py`, which uses them
as the fallback when this zip is missing.

## Everything else

`AlphabeticalAppGrid`, `appindicatorsupport`, `blur-my-shell`, `dash-to-dock`,
`just-perfection-desktop`, `space-bar`, `tilingshell` are the
extensions.gnome.org builds. `install-extensions.py` falls back to fetching
them from there by UUID when a zip is absent, so they can simply be replaced.

`tilingshell@ferrarodomenico.com` was Gnomarchy's dynamic tiling backend until
Forge replaced it, and it stays as the **manual** mode with
`enable-autotiling` off. Its auto-tiling places a new window into a fixed tile
of a static layout and never resizes the windows already on screen, which is
not the behaviour the distribution advertised; everything else it does --
drag-to-zone, snap assist, the layout editor, keyboard throws -- it does well.
Do not turn `enable-autotiling` back on in the installer.

`tactile@lundal.io` used to be here as the manual mode. Manual-mode Tiling
Shell does everything Tactile did, so it is no longer shipped.

`tophat@fflewddur.github.io` was the top-bar CPU/memory monitor. Its last
release (v24) stops at GNOME 50 and there is no build for 51 on
extensions.gnome.org or in its GitHub releases, so it is no longer shipped.
Bring it back once a release declares the GNOME version Gnomarchy runs.

Whenever Arch moves to a new GNOME, every zip here has to be checked against
it: `iso/tests/verify-install.sh` fails the install smoke test for any
deployed extension whose `metadata.json` does not list the installed
`gnome-shell` major version.
