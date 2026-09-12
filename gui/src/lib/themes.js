// Palettes for the theme gallery, read from each theme's alacritty.toml --
// the canonical palette per CLAUDE.md, and the same file the GTK CSS and the
// GNOME Terminal profile are generated from.
//
// This is a reader for the shape those files actually have (section headers
// and `key = "#hex"` lines), not a TOML parser. Pure: no gi:// imports.

const NORMAL_KEYS = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white'];

export function parsePalette(tomlText) {
  let section = '';
  const primary = {};
  const normal = {};

  for (const line of tomlText.split('\n')) {
    const trimmed = line.trim();
    if (trimmed === '' || trimmed.startsWith('#')) continue;

    const header = /^\[([^\]]+)\]$/.exec(trimmed);
    if (header !== null) { section = header[1]; continue; }

    const pair = /^([A-Za-z_]+)\s*=\s*"([^"]*)"$/.exec(trimmed);
    if (pair === null) continue;

    // Only these two sections are read; [colors.bright] and the rest are
    // deliberately ignored so they cannot overwrite the normal palette.
    if (section === 'colors.primary') primary[pair[1]] = pair[2];
    else if (section === 'colors.normal') normal[pair[1]] = pair[2];
  }

  if (primary.background === undefined || primary.foreground === undefined) return null;

  const filled = {};
  for (const key of NORMAL_KEYS) filled[key] = normal[key] ?? primary.foreground;

  return { background: primary.background, foreground: primary.foreground, normal: filled };
}

export function swatchColors(palette) {
  return NORMAL_KEYS.map((key) => palette.normal[key]);
}

export function prettyThemeName(dirName) {
  return dirName
    .split('-')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}
