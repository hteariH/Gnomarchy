// The one window: a sidebar of three pages beside a content pane.
//
// Every page is constructed up front rather than lazily, because the window is
// summoned by a hotkey and switching pages must not stutter. Three pages of
// widgets is cheap.

import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Gdk from 'gi://Gdk?version=4.0';
import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';

import { MenuPage } from './pages/menu.js';
import { KeybindingsPage } from './pages/keybindings.js';
import { ManualPage } from './pages/manual.js';

const PAGES = [
  { name: 'menu', title: 'Menu', icon: 'view-grid-symbolic' },
  { name: 'keybindings', title: 'Keybindings', icon: 'preferences-desktop-keyboard-symbolic' },
  { name: 'manual', title: 'Manual', icon: 'help-browser-symbolic' },
];

export const ControlWindow = GObject.registerClass(
  class ControlWindow extends Adw.ApplicationWindow {
    _init(application) {
      super._init({ application, title: 'Gnomarchy', defaultWidth: 980, defaultHeight: 680 });

      this._pages = {
        menu: new MenuPage(this),
        keybindings: new KeybindingsPage(this),
        manual: new ManualPage(this),
      };

      this._stack = new Gtk.Stack({ transitionType: Gtk.StackTransitionType.CROSSFADE });
      for (const { name } of PAGES) this._stack.add_named(this._pages[name].widget, name);

      this._sidebarList = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.SINGLE });
      this._sidebarList.add_css_class('navigation-sidebar');
      for (const { title, icon } of PAGES) {
        const row = new Adw.ActionRow({ title });
        row.add_prefix(new Gtk.Image({ iconName: icon }));
        this._sidebarList.append(row);
      }
      this._sidebarList.connect('row-selected', (_list, row) => {
        if (row === null) return;
        const { name } = PAGES[row.get_index()];
        this._stack.set_visible_child_name(name);
        this._pages[name].focusSearch();
      });

      const sidebar = new Adw.NavigationPage({
        title: 'Gnomarchy',
        child: new Adw.ToolbarView({
          content: new Gtk.ScrolledWindow({ child: this._sidebarList, vexpand: true }),
        }),
      });
      sidebar.get_child().add_top_bar(new Adw.HeaderBar());

      this._contentPage = new Adw.NavigationPage({ title: 'Menu', child: this._stack });

      this.set_content(new Adw.NavigationSplitView({
        sidebar,
        content: this._contentPage,
        minSidebarWidth: 180,
        maxSidebarWidth: 220,
      }));

      this._installKeyboardModel();
      this._watchTheme();
      this.showPage('menu');
    }

    showPage(name) {
      const index = PAGES.findIndex((page) => page.name === name);
      const target = index === -1 ? 0 : index;
      this._sidebarList.select_row(this._sidebarList.get_row_at_index(target));
      this._contentPage.set_title(PAGES[target].title);
      this._stack.set_visible_child_name(PAGES[target].name);
      this._pages[PAGES[target].name].focusSearch();
    }

    get currentPage() {
      return this._pages[this._stack.get_visible_child_name()];
    }

    // Esc unwinds the innermost active state and only closes the window when
    // there is none. Defined once here rather than per page, because the
    // Manual page would otherwise contradict the rule: there Esc must also
    // leave a rendered page.
    _installKeyboardModel() {
      const controller = new Gtk.EventControllerKey();
      // CAPTURE, so Esc and the digit shortcuts work even while a search entry
      // has the focus.
      controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);
      controller.connect('key-pressed', (_c, keyval, _code, state) => {
        const ctrl = (state & Gdk.ModifierType.CONTROL_MASK) !== 0;

        if (ctrl && keyval >= Gdk.KEY_1 && keyval <= Gdk.KEY_3) {
          this.showPage(PAGES[keyval - Gdk.KEY_1].name);
          return Gdk.EVENT_STOP;
        }

        if (ctrl && keyval === Gdk.KEY_f) {
          this.currentPage.focusSearch();
          return Gdk.EVENT_STOP;
        }

        if (keyval === Gdk.KEY_Escape) {
          if (!this.currentPage.escape()) this.close();
          return Gdk.EVENT_STOP;
        }

        // '/' and '?' are printable, so they are shortcuts only when the focus
        // is not in a text entry -- otherwise they could never be typed.
        const inEntry = this.get_focus() instanceof Gtk.Editable;
        if (!inEntry && keyval === Gdk.KEY_slash) {
          this.currentPage.focusSearch();
          return Gdk.EVENT_STOP;
        }
        if (!inEntry && keyval === Gdk.KEY_question) {
          this._showShortcuts();
          return Gdk.EVENT_STOP;
        }

        return Gdk.EVENT_PROPAGATE;
      });
      this.add_controller(controller);
    }

    _showShortcuts() {
      const dialog = new Adw.AlertDialog({
        heading: 'Keyboard',
        body: [
          'Ctrl+1 / Ctrl+2 / Ctrl+3\tGo to a page',
          'Up / Down\tMove through the list',
          '/ or Ctrl+F\tSearch this page',
          'Enter\tActivate',
          'Esc\tBack, then close',
          '?\tThis list',
        ].join('\n'),
      });
      dialog.add_response('close', 'Close');
      dialog.present(this);
    }

    // GTK4 does not reload gtk.css when it changes, so without this the app
    // keeps the old colours after `gnomarchy theme set`. The file is absent
    // until a theme has been applied at least once (and always absent on a
    // non-Gnomarchy host), which is not an error -- stock Adwaita is then the
    // correct appearance.
    _watchTheme() {
      const path = GLib.build_filenamev([
        GLib.get_user_config_dir(), 'gtk-4.0', 'gnomarchy-theme.css',
      ]);
      this._themeProvider = null;

      const file = Gio.File.new_for_path(path);
      this._themeMonitor = file.monitor_file(Gio.FileMonitorFlags.NONE, null);
      this._themeMonitor.connect('changed', () => this._loadThemeCss(path));
      this._loadThemeCss(path);
    }

    _loadThemeCss(path) {
      const display = this.get_display();

      if (this._themeProvider !== null) {
        Gtk.StyleContext.remove_provider_for_display(display, this._themeProvider);
        this._themeProvider = null;
      }

      if (!GLib.file_test(path, GLib.FileTest.EXISTS)) return;

      const provider = new Gtk.CssProvider();
      provider.load_from_path(path);
      Gtk.StyleContext.add_provider_for_display(
        display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
      );
      this._themeProvider = provider;
    }
  },
);
