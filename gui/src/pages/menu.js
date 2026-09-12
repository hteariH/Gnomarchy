// The command center: every system action on one searchable surface.
//
// The bash menu nested these behind submenus (menu_webapp, menu_capture,
// menu_snapshot, menu_system, menu_power); here typing filters across all of
// them at once. The action set is exactly the same -- this is a port, not an
// expansion.

import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';

import { run, runForOutput, runAndQuit } from '../lib/actions.js';
import { presentThemeGallery } from './theme-gallery.js';
import { escapePango } from '../lib/markdown.js';

export class MenuPage {
  constructor(window) {
    this._window = window;

    this._actions = [
      { group: 'Appearance', title: 'Theme', subtitle: 'Switch the system colour theme',
        kind: 'custom', perform: () => presentThemeGallery(this._window) },

      { group: 'Web Apps', title: 'Add a web app', subtitle: 'Turn a site into an application',
        kind: 'form', fields: ['Name', 'URL'],
        perform: (values) => run(['gnomarchy-webapp', 'add', values[0], values[1]]) },
      { group: 'Web Apps', title: 'List web apps', kind: 'output',
        argv: ['gnomarchy-webapp', 'list'] },
      { group: 'Web Apps', title: 'Remove a web app', kind: 'form', fields: ['Name'],
        perform: (values) => run(['gnomarchy-webapp', 'remove', values[0]]) },

      { group: 'Capture', title: 'Annotate a region', subtitle: 'Screenshot into Satty',
        kind: 'quit', argv: ['gnomarchy-capture', 'annotate'] },
      { group: 'Capture', title: 'Region to file', kind: 'quit',
        argv: ['gnomarchy-capture', 'region'] },
      { group: 'Capture', title: 'Whole screen', kind: 'quit',
        argv: ['gnomarchy-capture', 'screen'] },

      { group: 'Snapshots', title: 'Create a snapshot', kind: 'form', fields: ['Description'],
        perform: (values) => run([
          'gnomarchy-snapshot-create', values[0] === '' ? 'Manual snapshot' : values[0],
        ]) },
      { group: 'Snapshots', title: 'List snapshots', kind: 'output',
        argv: ['gnomarchy-snapshot-list'] },

      { group: 'System', title: 'Update everything', subtitle: 'System and Gnomarchy',
        kind: 'output', argv: ['gnomarchy-update'] },
      { group: 'System', title: 'GNOME shortcuts', kind: 'output',
        argv: ['gnomarchy-gnome-hotkeys'] },
      { group: 'System', title: 'Extensions', kind: 'output',
        argv: ['gnomarchy-gnome-extensions', 'list'] },
      { group: 'System', title: 'Gaming status', kind: 'output',
        argv: ['gnomarchy-gaming', 'status'] },
      { group: 'System', title: 'Restart GNOME Shell', kind: 'quit',
        argv: ['gnomarchy-gnome-restart'] },

      { group: 'Power', title: 'Lock', kind: 'quit', argv: ['loginctl', 'lock-session'] },
      { group: 'Power', title: 'Suspend', kind: 'quit', argv: ['systemctl', 'suspend'] },
      { group: 'Power', title: 'Log out', kind: 'confirm', confirm: 'Log out now?',
        argv: ['gnome-session-quit', '--logout', '--no-prompt'] },
      { group: 'Power', title: 'Reboot', kind: 'confirm', confirm: 'Reboot now?',
        argv: ['systemctl', 'reboot'] },
      { group: 'Power', title: 'Power off', kind: 'confirm', confirm: 'Power off now?',
        argv: ['systemctl', 'poweroff'] },
    ];

    this._search = new Gtk.SearchEntry({ placeholderText: 'Search actions' });
    this._search.connect('search-changed', () => this._refresh());
    this._search.connect('activate', () => this._activateFirst());

    this._groups = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 18 });

    const column = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 12,
      marginTop: 12, marginBottom: 12, marginStart: 12, marginEnd: 12 });
    column.append(this._search);
    column.append(new Gtk.ScrolledWindow({ child: this._groups, vexpand: true }));

    this.widget = column;
    this._refresh();
  }

  focusSearch() { this._search.grab_focus(); }

  escape() {
    if (this._search.get_text() !== '') {
      this._search.set_text('');
      return true;
    }
    return false;
  }

  _matching() {
    const needle = this._search.get_text().trim().toLowerCase();
    if (needle === '') return this._actions;
    return this._actions.filter((action) =>
      `${action.group} ${action.title} ${action.subtitle ?? ''}`.toLowerCase().includes(needle));
  }

  _refresh() {
    let child = this._groups.get_first_child();
    while (child !== null) {
      const next = child.get_next_sibling();
      this._groups.remove(child);
      child = next;
    }

    this._firstAction = null;
    let currentGroup = null;
    let list = null;

    for (const action of this._matching()) {
      if (action.group !== currentGroup) {
        currentGroup = action.group;
        const group = new Adw.PreferencesGroup({ title: currentGroup });
        list = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.NONE });
        list.add_css_class('boxed-list');
        group.add(list);
        this._groups.append(group);
      }

      const row = new Adw.ActionRow({
        title: escapePango(action.title),
        subtitle: escapePango(action.subtitle ?? ''),
        activatable: true,
      });
      row.connect('activated', () => this._perform(action));
      list.append(row);

      if (this._firstAction === null) this._firstAction = action;
    }
  }

  _activateFirst() {
    if (this._firstAction !== null) this._perform(this._firstAction);
  }

  _perform(action) {
    switch (action.kind) {
      case 'custom': action.perform(); break;
      case 'quit': runAndQuit(this._window, action.argv); break;
      case 'output': this._presentOutput(action); break;
      case 'form': this._presentForm(action); break;
      case 'confirm': this._presentConfirm(action); break;
    }
  }

  _presentConfirm(action) {
    const dialog = new Adw.AlertDialog({ heading: action.title, body: action.confirm });
    dialog.add_response('cancel', 'Cancel');
    dialog.add_response('go', action.title);
    dialog.set_response_appearance('go', Adw.ResponseAppearance.DESTRUCTIVE);
    dialog.set_default_response('go');
    dialog.set_close_response('cancel');
    dialog.connect('response', (_d, response) => {
      if (response === 'go') runAndQuit(this._window, action.argv);
    });
    dialog.present(this._window);
  }

  _presentForm(action) {
    const entries = action.fields.map((field) => new Adw.EntryRow({ title: field }));
    const list = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.NONE });
    list.add_css_class('boxed-list');
    for (const entry of entries) list.append(entry);

    const dialog = new Adw.AlertDialog({ heading: action.title, extraChild: list });
    dialog.add_response('cancel', 'Cancel');
    dialog.add_response('go', 'Apply');
    dialog.set_response_appearance('go', Adw.ResponseAppearance.SUGGESTED);
    dialog.set_default_response('go');
    dialog.set_close_response('cancel');
    dialog.connect('response', (_d, response) => {
      if (response === 'go') action.perform(entries.map((entry) => entry.get_text()));
    });
    dialog.present(this._window);
    entries[0].grab_focus();
  }

  _presentOutput(action) {
    const buffer = new Gtk.TextBuffer();
    const view = new Gtk.TextView({ buffer, editable: false, monospace: true });
    const scroller = new Gtk.ScrolledWindow({ child: view, vexpand: true, widthRequest: 620,
      heightRequest: 420 });

    const dialog = new Adw.Dialog({ title: action.title, contentWidth: 660, contentHeight: 480 });
    const toolbar = new Adw.ToolbarView({ content: scroller });
    toolbar.add_top_bar(new Adw.HeaderBar());
    dialog.set_child(toolbar);
    dialog.present(this._window);

    runForOutput(
      action.argv,
      (line) => buffer.insert(buffer.get_end_iter(), `${line}\n`, -1),
      (successful) => {
        if (!successful) {
          buffer.insert(buffer.get_end_iter(), '\n[command exited with an error]\n', -1);
        }
      },
    );
  }
}
