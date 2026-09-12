// Every keybinding in effect, searchable. Task 8 makes the rows editable.

import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';

import { formatAccel } from '../lib/accel.js';
import { readBindings, writeBinding, findConflict, onBindingsChanged } from '../lib/keysources.js';
import { presentAccelDialog } from './accel-dialog.js';
import { run } from '../lib/actions.js';
import { escapePango } from '../lib/markdown.js';

export class KeybindingsPage {
  constructor(window) {
    this._window = window;

    this._search = new Gtk.SearchEntry({ placeholderText: 'Search keybindings' });
    this._search.connect('search-changed', () => this._refresh());

    this._groups = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 18 });

    const column = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 12,
      marginTop: 12, marginBottom: 12, marginStart: 12, marginEnd: 12 });
    column.append(this._search);

    // Delegates to gnomarchy-keymap via the existing reset path, so
    // bin/gnomarchy-keymap stays the only definition of what the defaults are.
    const reset = new Gtk.Button({ label: 'Reset to layout defaults', halign: Gtk.Align.END });
    reset.connect('clicked', () => {
      const dialog = new Adw.AlertDialog({
        heading: 'Reset shortcuts',
        body: 'Re-apply the keyboard layout this machine is set to. Your changes to shortcuts will be lost.',
      });
      dialog.add_response('cancel', 'Cancel');
      dialog.add_response('reset', 'Reset');
      dialog.set_response_appearance('reset', Adw.ResponseAppearance.DESTRUCTIVE);
      dialog.set_close_response('cancel');
      dialog.connect('response', (_d, response) => {
        if (response === 'reset') run(['gnomarchy-keybindings', 'reset']);
      });
      dialog.present(this._window);
    });
    column.append(reset);

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
        const group = new Adw.PreferencesGroup({ title: escapePango(currentSection) });
        list = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.NONE });
        list.add_css_class('boxed-list');
        group.add(list);
        this._groups.append(group);
      }

      const row = new Adw.ActionRow({
        title: escapePango(binding.description),
        subtitle: escapePango(formatAccel(binding.accel)),
        activatable: true,
      });
      row.gnomarchyBinding = binding;
      row.connect('activated', () => this._edit(binding));
      list.append(row);
    }
  }

  _edit(binding) {
    presentAccelDialog(this._window, binding, {
      onAccel: (accel) => {
        if (accel === '') { writeBinding(binding, ''); this._reload(); return; }

        const clash = findConflict(this._bindings, accel, binding.id);
        if (clash === null) { writeBinding(binding, accel); this._reload(); return; }

        this._confirmReplace(binding, accel, clash);
      },
    });
  }

  _confirmReplace(binding, accel, clash) {
    const dialog = new Adw.AlertDialog({
      heading: 'Already in use',
      body: `${escapePango(formatAccel(accel))} is bound to “${escapePango(clash.description)}”.\n`
        + 'Replacing it will leave that action with no shortcut.',
    });
    dialog.add_response('cancel', 'Cancel');
    dialog.add_response('replace', 'Replace');
    dialog.set_response_appearance('replace', Adw.ResponseAppearance.DESTRUCTIVE);
    dialog.set_close_response('cancel');
    dialog.connect('response', (_d, response) => {
      if (response !== 'replace') return;
      writeBinding(clash, '');
      writeBinding(binding, accel);
      this._reload();
    });
    dialog.present(this._window);
  }
}
