# Where the bundled extensions come from

Every zip in this directory is installed by `install/desktop/install-extensions.py`
during the chroot stage, before any session exists. All of them are the
published extensions.gnome.org builds and can be refreshed from there.

## The extensions

`AlphabeticalAppGrid`, `appindicatorsupport`, `blur-my-shell`, `dash-to-dock`,
`just-perfection-desktop`, `space-bar`, `tilingshell` are the
extensions.gnome.org builds. `install-extensions.py` falls back to fetching
them from there by UUID when a zip is absent, so they can simply be replaced.

`tilingshell@ferrarodomenico.com` is Gnomarchy's tiling, with
`enable-autotiling` off. Its auto-tiling places a new window into a fixed tile
of a static layout and never resizes the windows already on screen, which is
not the behaviour the distribution advertised; everything else it does --
drag-to-zone, snap assist, the layout editor, keyboard throws -- it does well.
Do not turn `enable-autotiling` back on in the installer.

`tactile@lundal.io` and `forge@jmmaranan.com` used to be here. Tiling Shell
does everything Tactile did. Forge gave a second, dynamic tree-tiling mode;
it was dropped to keep one tiler and to stop depending on a beta build of a
fork -- the extensions.gnome.org Forge stops at GNOME 49.

`tophat@fflewddur.github.io` was the top-bar CPU/memory monitor. Its last
release (v24) stops at GNOME 50 and there is no build for 51 on
extensions.gnome.org or in its GitHub releases, so it is no longer shipped.
Bring it back once a release declares the GNOME version Gnomarchy runs.

Whenever Arch moves to a new GNOME, every zip here has to be checked against
it: `iso/tests/verify-install.sh` fails the install smoke test for any
deployed extension whose `metadata.json` does not list the installed
`gnome-shell` major version.
