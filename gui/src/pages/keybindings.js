// Every keybinding in effect, searchable. Task 8 makes the rows editable.

import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';

import { formatAccel } from '../lib/accel.js';
import { readBindings, onBindingsChanged } from '../lib/keysources.js';

export class KeybindingsPage {
  constructor(window) {
    this._window = window;

    this._search = new Gtk.SearchEntry({ placeholderText: 'Search keybindings' });
    this._search.connect('search-changed', () => this._refresh());

    this._groups = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 18 });

    const column = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 12,
      marginTop: 12, marginBottom: 12, marginStart: 12, marginEnd: 12 });
    column.append(this._search);
    column.append(new Gtk.ScrolledWindow({ child: this._groups, vexpand: true }));

    this.widget = column;
    this._reload();

    // The list must never be stale if something changes dconf underneath it.
    onBindingsChanged(() => this._reload());
  }

  focusSearch() { this._search.grab_focus(); }

  escape() {
    if (this._search.get_text() !== '') {
      this._search.set_text('');
      return true;
    }
    return false;
  }

  _reload() {
    this._bindings = readBindings();
    this._refresh();
  }

  _matching() {
    const needle = this._search.get_text().trim().toLowerCase();
    if (needle === '') return this._bindings;
    return this._bindings.filter((binding) =>
      `${binding.description} ${formatAccel(binding.accel)} ${binding.section}`
        .toLowerCase().includes(needle));
  }

  _refresh() {
    let child = this._groups.get_first_child();
    while (child !== null) {
      const next = child.get_next_sibling();
      this._groups.remove(child);
      child = next;
    }

    let currentSection = null;
    let list = null;

    for (const binding of this._matching()) {
      if (binding.section !== currentSection) {
        currentSection = binding.section;
        const group = new Adw.PreferencesGroup({ title: currentSection });
        list = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.NONE });
        list.add_css_class('boxed-list');
        group.add(list);
        this._groups.append(group);
      }

      const row = new Adw.ActionRow({
        title: binding.description,
        subtitle: formatAccel(binding.accel),
        activatable: true,
      });
      row.gnomarchyBinding = binding;
      list.append(row);
    }
  }
}
