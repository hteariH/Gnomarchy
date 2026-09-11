# Where the bundled extensions come from

Every zip in this directory is installed by `install/desktop/install-extensions.py`
during the chroot stage, before any session exists. Most of them are the
published extensions.gnome.org builds and can be refreshed from there.

One cannot, and that is the reason this file exists.

## forge@jmmaranan.com

| | |
|---|---|
| source | <https://github.com/jcrussell/forge> (fork of `forge-ext/forge`) |
| release | `v49-90-beta.3`, published 2026-08-09 |
| version-name | `v49-90-beta.3` |
| shell-version | 45, 46, 47, 48, 49, **50** |
| sha256 | `a0a11ded2157286253ed70f1f966cc3b7158d1a1927bd88598ae356dea3543d8` |

**Do not refresh this one from extensions.gnome.org.** The Forge listed there
is `forge-ext/forge`, which stops at GNOME 49 — its own `metadata.json` says
so, and upstream's description reads "Needs a new maintainer". Installing that
build on Gnomarchy's GNOME 50 gives an extension the shell refuses to load.
The fork above is maintained, declares 50, and is what `gnomarchy tiling
enable` expects.

The zip already contains `schemas/gschemas.compiled`, so it loads even if the
compile step in `install-extensions.py` is skipped.

To refresh it:

```bash
tag=v49-90-beta.3   # or the newer tag you are moving to
base="https://github.com/jcrussell/forge/releases/download/$tag"
curl -fsSL -o "forge@jmmaranan.com.zip" "$base/forge%40jmmaranan.com.zip"
curl -fsSL "$base/SHA256SUMS"
sha256sum "forge@jmmaranan.com.zip"      # must match SHA256SUMS
unzip -p "forge@jmmaranan.com.zip" metadata.json | grep shell-version
```

The last line is not optional: a build that does not list `"50"` must not be
committed. Update the table above in the same commit, and update the pinned
URL and checksum in `install/desktop/install-extensions.py`, which uses them
as the fallback when this zip is missing.

## Everything else

`AlphabeticalAppGrid`, `appindicatorsupport`, `blur-my-shell`, `dash-to-dock`,
`just-perfection-desktop`, `space-bar`, `tilingshell`, `tophat` are the
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
