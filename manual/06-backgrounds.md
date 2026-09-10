# Backgrounds

```bash
gnomarchy backgrounds
gnomarchy backgrounds --list
gnomarchy backgrounds --verify
```

## Where wallpapers come from

They are downloaded onto your machine at install time from the upstream Omarchy
repository, pinned to a specific commit, and every file is checked against a
recorded hash before being installed. A file that fails verification is
discarded rather than used.

Gnomarchy does not redistribute them. Omarchy ships no attribution for these
images and the only source it names is published with no licence at all, so
committing them here would mean claiming rights over artwork of unknown
authorship in a project that publishes installable ISOs. The reasoning is in
`BACKGROUNDS.md`.

## Offline

Every theme also ships a small generated SVG wallpaper. Those are Gnomarchy's
own and are installed alongside the downloads, so a machine with no network
still has a working wallpaper for every theme.

## Using your own

Drop images here and they win over everything else:

    ~/.config/gnomarchy/backgrounds/<theme>/

Resolution order, most specific first:

1. `~/.config/gnomarchy/backgrounds/<theme>/`
2. `/usr/share/backgrounds/gnomarchy/<theme>/` - downloaded
3. the theme's bundled SVG - offline fallback

Within a folder, numbered files are preferred over the small `omarchy.*` tile.
