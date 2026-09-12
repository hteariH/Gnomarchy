import Gtk from 'gi://Gtk?version=4.0';

export class ManualPage {
  constructor(window) {
    this._window = window;
    this.widget = new Gtk.Label({ label: 'Manual' });
  }

  focusSearch() {}

  escape() { return false; }
}
