// Gnomarchy Control Center.
//
// Launched by bin/gnomarchy-menu, bin/gnomarchy-keybindings and
// bin/gnomarchy-manual as: gjs -m <this file> --page=<name>
//
// HANDLES_COMMAND_LINE gives single-instance behaviour: pressing Super+K while
// the window is already open on the Manual page switches page and presents the
// existing window instead of opening a second one.

import system from 'system';
import Gio from 'gi://Gio';
import Gdk from 'gi://Gdk?version=4.0';
import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';

import { ControlWindow } from './window.js';
import { dataFile } from './lib/paths.js';

const VALID_PAGES = ['menu', 'keybindings', 'manual'];

const application = new Adw.Application({
  applicationId: 'org.gnomarchy.ControlCenter',
  flags: Gio.ApplicationFlags.HANDLES_COMMAND_LINE,
});

let window = null;

application.connect('startup', () => {
  const provider = new Gtk.CssProvider();
  provider.load_from_path(dataFile('gnomarchy-gui.css'));
  Gtk.StyleContext.add_provider_for_display(
    Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
  );
});

application.connect('command-line', (_app, commandLine) => {
  let page = 'menu';
  for (const argument of commandLine.get_arguments()) {
    if (argument.startsWith('--page=')) page = argument.slice('--page='.length);
  }
  if (!VALID_PAGES.includes(page)) {
    commandLine.printerr_literal(`Unknown page: ${page}\n`);
    return 1;
  }

  if (window === null) window = new ControlWindow(application);
  window.showPage(page);
  window.present();
  return 0;
});

// GJS does not translate Gio.Application.run()'s return value into the
// process exit code on its own (verified: the "command-line" handler's
// return reaches run()'s result, but the process still exits 0 unless told
// otherwise) -- so the invalid-page case from the CLI would silently report
// success. Capture it and exit explicitly.
const status = application.run([system.programInvocationName, ...system.programArgs]);
system.exit(status);
