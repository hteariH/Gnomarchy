import Gtk from 'gi://Gtk?version=4.0';

export class MenuPage {
  constructor(window) {
    this._window = window;
    this.widget = new Gtk.Label({ label: 'Menu' });
  }

  focusSearch() {}

  escape() { return false; }
}
