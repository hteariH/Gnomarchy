import Gtk from 'gi://Gtk?version=4.0';

export class KeybindingsPage {
  constructor(window) {
    this._window = window;
    this.widget = new Gtk.Label({ label: 'Keybindings' });
  }

  focusSearch() {}

  escape() { return false; }
}
