// A grid of theme cards, each showing the palette from that theme's
// alacritty.toml. Applying runs gnomarchy-theme-set, and the window's file
// monitor re-themes the app as soon as it writes the GTK CSS.

import GLib from 'gi://GLib';
import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';

import { parsePalette, swatchColors, prettyThemeName } from '../lib/themes.js';
import { GNOMARCHY_PATH, listDir, readTextFile } from '../lib/paths.js';
import { run } from '../lib/actions.js';
import { escapePango } from '../lib/markdown.js';

function themeDirectories() {
  const roots = [
    GLib.build_filenamev([GNOMARCHY_PATH, 'themes']),
    GLib.build_filenamev([GLib.get_user_config_dir(), 'gnomarchy', 'themes']),
  ];

  const found = new Map();
  for (const root of roots) {
    for (const name of listDir(root)) {
      const toml = readTextFile(GLib.build_filenamev([root, name, 'alacritty.toml']));
      if (toml === null) continue;
      const palette = parsePalette(toml);
      if (palette !== null) found.set(name, palette);
    }
  }
  return [...found.entries()].sort((a, b) => a[0].localeCompare(b[0]));
}

function swatchStrip(palette) {
  const strip = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, heightRequest: 14 });
  strip.add_css_class('gnomarchy-swatch-strip');
  for (const colour of swatchColors(palette)) {
    const cell = new Gtk.Box({ hexpand: true });
    cell.add_css_class('gnomarchy-swatch');
    const provider = new Gtk.CssProvider();
    provider.load_from_string(`box { background-color: ${colour}; }`);
    cell.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    strip.append(cell);
  }
  return strip;
}

export function presentThemeGallery(window) {
  const list = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.SINGLE });
  list.add_css_class('boxed-list');

  for (const [name, palette] of themeDirectories()) {
    // The title comes from a user theme directory name, unescaped like every
    // other row-building site -- a directory named "light&dark" would blank
    // this row (Adw.ActionRow's title defaults to use-markup: true).
    const row = new Adw.ActionRow({ title: escapePango(prettyThemeName(name)), activatable: true });
    row.add_suffix(swatchStrip(palette));
    row.gnomarchyTheme = name;
    list.append(row);
  }

  const dialog = new Adw.Dialog({ title: 'Theme', contentWidth: 460, contentHeight: 560 });
  const view = new Adw.ToolbarView({
    content: new Gtk.ScrolledWindow({ child: list, vexpand: true, marginTop: 12,
      marginBottom: 12, marginStart: 12, marginEnd: 12 }),
  });
  view.add_top_bar(new Adw.HeaderBar());
  dialog.set_child(view);

  list.connect('row-activated', (_l, row) => {
    run(['gnomarchy-theme-set', row.gnomarchyTheme]);
    dialog.close();
  });

  window.trackDialog(dialog);
  dialog.present(window);
  list.grab_focus();
}
