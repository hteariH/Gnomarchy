// The manual: a searchable list of pages, and a reader.
//
// Adw.NavigationView gives the list -> page transition and the back button;
// the window's Esc rule pops it at level 3.

import GLib from 'gi://GLib';
import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';
import Pango from 'gi://Pango';

import { renderBlocks, escapePango } from '../lib/markdown.js';
import { pageTitle, searchPages } from '../lib/manual.js';
import { GNOMARCHY_PATH, listDir, readTextFile } from '../lib/paths.js';

// libadwaita's own typography classes, so headings follow the system font
// scale rather than a size invented here.
const BLOCK_CSS_CLASS = {
  h1: 'title-1',
  h2: 'title-3',
  h3: 'heading',
  p: 'body',
  ul: 'body',
  ol: 'body',
  code: 'gnomarchy-code',
};

export class ManualPage {
  constructor(window) {
    this._window = window;
    this._pages = this._loadPages();

    this._search = new Gtk.SearchEntry({ placeholderText: 'Search the manual' });
    this._search.connect('search-changed', () => this._refresh());
    // Down from the entry moves into the results, so filtering and choosing
    // are one continuous keyboard motion.
    this._search.connect('activate', () => this._activateFirst());

    this._list = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.SINGLE });
    this._list.add_css_class('boxed-list');
    this._list.connect('row-activated', (_l, row) => this._open(row.gnomarchyPage));

    const listBox = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 12 });
    listBox.append(this._search);
    listBox.append(new Gtk.ScrolledWindow({ child: this._list, vexpand: true }));
    listBox.set_margin_top(12);
    listBox.set_margin_bottom(12);
    listBox.set_margin_start(12);
    listBox.set_margin_end(12);

    const listPage = new Adw.NavigationPage({ title: 'Manual', child: listBox });

    this._navigation = new Adw.NavigationView();
    this._navigation.add(listPage);

    this.widget = this._navigation;
    this._refresh();
  }

  focusSearch() {
    this._search.grab_focus();
  }

  escape() {
    // Level 3 of the window's Esc rule: leave a rendered page first.
    if (this._navigation.get_navigation_stack().get_n_items() > 1) {
      this._navigation.pop();
      return true;
    }
    // Then level 2.
    if (this._search.get_text() !== '') {
      this._search.set_text('');
      return true;
    }
    return false;
  }

  _loadPages() {
    const dir = GLib.build_filenamev([GNOMARCHY_PATH, 'manual']);
    return listDir(dir)
      .filter((name) => name.endsWith('.md'))
      .map((name) => ({
        file: name,
        title: pageTitle(name),
        text: readTextFile(GLib.build_filenamev([dir, name])) ?? '',
      }));
  }

  _refresh() {
    let row = this._list.get_first_child();
    while (row !== null) {
      const next = row.get_next_sibling();
      this._list.remove(row);
      row = next;
    }

    for (const { page, snippet } of searchPages(this._pages, this._search.get_text())) {
      const actionRow = new Adw.ActionRow({
        title: escapePango(page.title),
        subtitle: escapePango(snippet),
        activatable: true,
      });
      actionRow.gnomarchyPage = page;
      this._list.append(actionRow);
    }
  }

  _activateFirst() {
    const first = this._list.get_row_at_index(0);
    if (first !== null) this._open(first.gnomarchyPage);
  }

  _open(page) {
    const body = new Gtk.Box({
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 4,
    });
    body.add_css_class('gnomarchy-manual-body');

    for (const block of renderBlocks(page.text)) {
      const label = new Gtk.Label({
        label: block.markup,
        useMarkup: true,
        wrap: true,
        wrapMode: Pango.WrapMode.WORD_CHAR,
        xalign: 0,
        selectable: true,
      });
      label.add_css_class(BLOCK_CSS_CLASS[block.type]);
      body.append(label);
    }

    const scroller = new Gtk.ScrolledWindow({ child: body, vexpand: true });
    this._navigation.push(new Adw.NavigationPage({ title: page.title, child: scroller }));
  }
}
