# Gnomarchy Control Center — design

**Date:** 2026-09-12
**Status:** approved, not yet implemented

Replace the three terminal UIs — `gnomarchy menu`, `gnomarchy keybindings`
and `gnomarchy manual` — with one keyboard-driven GTK4/libadwaita
application, keeping the bash commands as a non-interactive fallback.

## Why

All three commands do the same awkward thing: a keybinding has no
controlling terminal, so each one spawns `gnome-terminal` and draws a TUI
inside it (`bin/gnomarchy-menu:15`, `bin/gnomarchy-manual:21`,
`bin/gnomarchy-keybindings:20`). The result is a terminal window
pretending to be a desktop app, on a distribution whose entire premise is
a tuned GNOME desktop.

Two further costs of the current design disappear with it:

- `bin/gnomarchy-keybindings` parses the output of `gsettings` and carries
  an apology in its own source for having to special-case `@as []`
  (`bin/gnomarchy-keybindings:36`). Reading dconf through `Gio.Settings`
  is typed, and — unlike string parsing — can also write.
- The menu's actions are buried in nested submenus (`menu_webapp`,
  `menu_capture`, `menu_snapshot`, `menu_system`, `menu_power`). One
  searchable surface makes every action reachable with a few keystrokes.

## Decisions

Four decisions were settled before the design, and the rest follows from
them:

1. **The GUI is the face; the CLI stays as a fallback.** The bash commands
   are demoted to non-interactive output (`--list`, `--grep`, open a page
   by name) and keep working over SSH, in a TTY, and on a half-installed
   system. `bin/gnomarchy-manual`'s own header argues for exactly this:
   the troubleshooting page must be reachable on the machine where you
   most need it.
2. **One control-center window with a sidebar**, not three transient
   palettes. Each of the three shortcuts summons the same window to its
   own page.
3. **Full control center: the keybindings page can rebind keys**, not just
   list them.
4. **GTK4 + libadwaita in GJS.**

### Why GJS, and not Rust or Tauri

The decisive argument is the distribution model, not language taste.
Gnomarchy ships as a *source* repository at `~/.local/share/gnomarchy`
that `gnomarchy update` advances with `git pull`. GJS has no build step,
so the app updates by precisely that mechanism, like every other file in
the repo. Three things follow for free:

- **Theming already exists.** `bin/gnomarchy-theme-set:257` writes
  `~/.config/gtk-4.0/gnomarchy-theme.css`, redefining libadwaita's own
  named colours (`window_bg_color`, `sidebar_bg_color`, `card_bg_color`,
  `headerbar_bg_color`). `gtk.css` imports it and GTK4 auto-loads that for
  every GTK4 app, so an Adwaita app built from stock widgets is themed by
  all 22 themes with zero lines of theming code.
- **dconf is a native API.** The editable keybindings page needs typed
  read *and* write access to relocatable schema paths. `Gio.Settings`
  provides it.
- **Cold start is roughly 150 ms**, which a hotkey-summoned window needs.
  PyGObject was rejected on this point alone: 300–400 ms is felt on every
  summon.

A compiled binary does not fit a git-pulled config repository. Rust would
force either a toolchain on every user's machine and a rebuild on any
update that touches the app, or prebuilt release assets plus a fetch step
in `gnomarchy update` — new infrastructure, a new failure mode, and the
repo stops being just a config repo. Tauri adds three costs on top of
that: `webkit2gtk-4.1` (~100 MB, which nothing else on the system pulls),
an npm build, and a second theming system — the 22 palettes would have to
be re-emitted as web CSS and kept in sync forever. Tauri earns its premium
when one UI must run on macOS, Windows and Linux. This app is GNOME-only
and wants to look like GNOME.

The cost accepted in exchange: JavaScript, no type checking, and no
Markdown library. See *Verification* for how the missing compiler is
replaced.

## Architecture

One `Adw.Application`, id `org.gnomarchy.ControlCenter`, using
`Adw.NavigationSplitView`: a sidebar of three rows (Menu, Keybindings,
Manual) beside a content pane.

```
gui/
  src/main.js              Adw.Application, split view, global keys
  src/pages/menu.js
  src/pages/keybindings.js
  src/pages/manual.js
  src/lib/dconf.js         Gio.Settings wrappers (read + write)
  src/lib/markdown.js      Markdown -> Pango markup
  src/lib/themes.js        parse themes/*/alacritty.toml palettes
  data/gnomarchy-gui.css   only what the theme variables cannot express
  data/org.gnomarchy.ControlCenter.desktop
```

`gui/` is a new top-level directory and deliberately **not** under `bin/`:
`install/config/symlinks.sh:26` symlinks every `bin/gnomarchy*` file into
`/usr/local/bin`, which would publish internal modules as commands.

Each module has one job and a stated interface. `lib/markdown.js`,
`lib/themes.js` and the accelerator logic in `lib/dconf.js` are pure
functions over strings, which is what makes them testable without a
display (see *Verification*).

### Entry points

The three existing commands remain the entry points. No new keybindings,
no dconf migration for bindings, and nothing in the documentation about
which key does what has to change.

| Command | New behaviour |
|---|---|
| `gnomarchy-menu` | `exec gjs -m .../main.js --page=menu` |
| `gnomarchy-keybindings` | `--page=keybindings`; `--list` and `reset` stay pure text |
| `gnomarchy-manual` | `--page=manual`; `--list`, `--grep` and `<page>` stay pure text |

Each falls back to today's gum TUI when `gjs` is missing or both
`$WAYLAND_DISPLAY` and `$DISPLAY` are unset — the TTY and half-installed
cases. That code already exists and is kept. The terminal re-exec blocks
are deleted: the GUI is the window now.

**Single instance.** `Gio.ApplicationFlags.HANDLES_COMMAND_LINE` with a
fixed application id. Pressing Super+K while the window is open on Manual
switches page and focuses the existing window rather than opening a
second one.

### Keyboard model

The application must be fully operable without a mouse. No control is
reachable only by clicking.

| Key | Action |
|---|---|
| `Ctrl+1` / `Ctrl+2` / `Ctrl+3` | jump to a page |
| `Up` / `Down` | walk the sidebar or the focused list, including from inside the search entry |
| `/` or `Ctrl+F` | focus the page's search entry |
| `Enter` | activate the focused row |
| `Esc` | step back one level; close the window at the outermost level |
| `?` | open a `Gtk.ShortcutsWindow` listing all of the above |

Arrowing through results from within the search entry is explicit: it
removes the Tab dance that would otherwise sit between typing a filter and
choosing a result.

`/` and `?` are printable characters, so they act as shortcuts **only when
focus is not in a text entry**. Inside a search entry they type themselves.
`Ctrl+F` always works, which is why both are offered.

`Esc` is defined as one rule, not per-page, because the Manual page
otherwise contradicts it — there, `Esc` must leave a rendered page as well
as clear a search. It unwinds the innermost state that is active, and
closes the window only when none is:

1. a dialog is open — close the dialog
2. the search entry is non-empty — clear it
3. the content pane has been navigated into (a rendered manual page) —
   go back
4. otherwise — close the window

## Pages

### Menu

A searchable list of actions in `Adw.PreferencesGroup` sections —
Appearance, Capture, Web Apps, Snapshots, System, Power. Typing filters
across every action at once, so today's nested submenus collapse into one
flat surface. *Keybindings* and *Manual* leave the menu; they are sidebar
pages now.

Four behaviours, because the actions are not alike:

- **Fire-and-forget** (Lock, Suspend) — run, then quit.
- **Produces output** (Update everything, Extensions, Gaming status) —
  `Gio.Subprocess` streaming stdout into a scrollable result pane.
  Today `gnomarchy update` blocks a terminal behind
  `gum input --placeholder "Press Enter to continue"`.
- **Needs the window gone** (all three Capture actions) — hide the window,
  spawn, quit. Today's `exec` achieved this by replacing the terminal.
- **Destructive** (Log out, Reboot, Power off) — `Adw.AlertDialog`, `Enter`
  confirms and `Esc` cancels, matching today's `gum confirm`.

**Theme** opens a grid of cards, each showing a swatch strip parsed from
`themes/<name>/alacritty.toml` — the canonical palette per CLAUDE.md.
`Enter` applies it by running `gnomarchy-theme-set`.

GTK4 does not reload `gtk.css` when it changes, so the application would
otherwise keep the old colours after applying a theme. A `Gio.FileMonitor`
on `~/.config/gtk-4.0/gnomarchy-theme.css` reloads the CSS provider, which
also buys live re-theming as the user arrows through the grid.

### Keybindings

Reads the same six sources as today — custom media-key slots, Tiling
Shell, `org.gnome.desktop.wm.keybindings`, `org.gnome.shell.keybindings`,
`org.gnome.mutter.keybindings`, and Tactile's `show-tiles` — but through
`Gio.Settings` rather than by parsing `gsettings` output. Descriptions
continue to come from each schema's own summary
(`Gio.SettingsSchemaKey.get_summary()`), so they cannot drift from the
schemas.

Editing: `Enter` on a row opens a capture dialog. Press a combination to
set it, `Backspace` to unbind, `Esc` to cancel.

- **Normalisation** through `Gtk.accelerator_parse` and
  `Gtk.accelerator_name`. Bare modifiers and unmodified printable keys are
  rejected, as GNOME Settings does.
- **Conflict detection** scans all six sources for the same normalised
  accelerator, names the row currently holding it, and offers Replace
  (which unbinds the other) or Cancel.
- **Writing**: schema keys of type `as` via `set_strv`; custom slots are
  relocatable, so `Gio.Settings.new_with_path()` then
  `set_string('binding', …)`.
- **Live refresh** via the `Gio.Settings::changed` signal, so the list is
  never stale if something changes underneath it.

Two limits, both to avoid overlapping what `bin/gnomarchy-keymap` owns:

1. **Reset does not own a copy of the defaults.** It runs
   `gnomarchy-keymap` with the contents of
   `~/.config/gnomarchy/current/keymap` — the existing
   `gnomarchy-keybindings reset` path. One source of truth for what the
   defaults are.
2. **Existing Gnomarchy commands can be rebound; new ones cannot be
   invented.** Allocating arbitrary `custom<N>` slots would collide with
   `gnomarchy-keymap`'s management of custom0–custom8, and GNOME Settings
   already does that job.

**Open technical risk.** Under Wayland, GNOME grabs compositor-level
shortcuts before they reach an application, so a capture dialog may never
see `Super+Q`. GNOME Settings works around this with
`Gdk.Toplevel.inhibit_system_shortcuts()`. This is resolved by a spike
before the page is built (see *Order of work*). If it cannot be made to
work, the editor degrades to an entry field in which the user types the
accelerator, and everything else in this section stands.

### Manual

A search entry over the 17 pages. Search is full-text and shows matching
snippets, the way `--grep` does today, rather than matching titles only.
`Enter` pushes the rendered page into an `Adw.NavigationView`; `Alt+Left` or
`Esc` at level 3 of the rule above goes back.

`lib/markdown.js` renders to Pango markup in stacked selectable labels.
The supported set is matched to what the pages actually contain, measured
rather than assumed — across 722 lines there are 17 `#`, 60 `##`, 2 `###`,
26 fenced code blocks, 41 list items, 20 bold spans and 121 inline code
spans, and **zero tables, links, images or blockquotes**:

> headings, paragraphs, bold, italic, inline code, fenced code blocks,
> unordered lists, ordered lists.

Anything outside that set renders **literally rather than being silently
dropped**, and CI asserts the manual uses only the supported subset, so
adding a table to a page fails the build instead of quietly rendering as
`| a | b |`.

## Packaging and install

Add `gjs`, `gtk4` and `libadwaita` to `install/gnomarchy-base.packages`.
All three were verified present in `extra` against the real package
database, per CLAUDE.md. `gnome-shell` already pulls all three
transitively; listing them explicitly makes the dependency a stated fact
rather than a lucky inheritance. `gum` stays, because the fallback path
uses it.

**Nothing is built and no new executable is added.** `gui/src/main.js` is
invoked as `gjs -m <path>` and needs no `+x` bit, which sidesteps the
Windows file-mode trap described in CLAUDE.md. The only executables
touched are the three `bin/` scripts, which already exist and are already
executable.

One new stage, `install/config/control-center.sh`, following the pattern
of `install/config/hooks.sh`: copy
`default/applications/org.gnomarchy.ControlCenter.desktop` into
`~/.local/share/applications/` so the app is reachable from the GNOME
Overview as well as by hotkey.

That is the whole installation. Note what is absent: no dconf writes, no
first-run work, no desktop stage. Because the three existing commands
remain the entry points and `install/desktop/set-gnome-hotkeys.sh:67-77`
already binds them, the GUI needs nothing from the seat, and every part of
it installs cleanly inside `arch-chroot`. The chroot boundary does not
apply to it. This was a goal of the entry-point decision, not an accident.

## Migration

`migrations/<YYYY-MM-DD-HHMM>-control-center-gui.sh`. Adding packages to
the list reaches new installs only, so an existing machine needs:

1. `sudo pacman -S --needed --noconfirm gjs gtk4 libadwaita`
2. deployment of the `.desktop` file

Idempotent by construction (`--needed`, `cp -f`), and it needs no session
bus, so unlike most migrations here it can succeed anywhere. It
deliberately does not touch keybindings: they already point at
`gnomarchy-menu`, `gnomarchy-keybindings` and `gnomarchy-manual`, whose
names do not change. `gui/` itself arrives with the `git pull` that
`gnomarchy update` already performs.

## Verification

Both layers, per CLAUDE.md, with each check tied to a way this can break.

`iso/tests/verify-install.sh` — offline, against the mounted image, with
all four subvolumes mounted:

- `gjs`, `gtk4` and `libadwaita` are installed
- `gui/src/main.js` and the `.desktop` file are present
- the terminal re-exec blocks are gone from all three `bin/` scripts,
  which catches a half-applied port

`iso/tests/verify-session.sh` — inside a real autologin session, extending
the existing `ok`/`no` harness:

- launch `gnomarchy-menu` and assert that `org.gnomarchy.ControlCenter`
  owns its name on the session bus within a timeout
- assert the manual uses only renderable Markdown

The D-Bus check matters more than it looks. GJS has no compile step, so
nothing catches a syntax error or a bad import until runtime — the one
real weakness of the toolchain choice. An application that successfully
owns its bus name has parsed every module and constructed its window, so
this single check stands in for the compiler the stack does not have.

`iso/tests/capture-screenshots.sh` gains a shot of each of the three
pages.

**Unit tests, runnable without a display.** The logic-bearing parts are
pure functions: Markdown to Pango markup, accelerator normalisation,
conflict detection, and `alacritty.toml` parsing. These live in
`gui/tests/` under a plain `gjs` runner and are written test-first.

A stated limit: this work is being done from a Windows worktree where
GTK4 cannot run at all. The pure-function tests are the only part
verifiable locally; everything visual is verified in the QEMU session run.

## Documentation

CLAUDE.md treats documentation as a claim about the code, so these change
in the same commit as the behaviour: `README.md`, `AGENTS.md`,
`manual/07-the-menu.md` and `manual/03-keybindings.md` all currently
describe terminal interfaces.

## Order of work

1. **Spike `Gdk.Toplevel.inhibit_system_shortcuts()`** (~20 lines): can a
   dialog receive `Super+Q` under Wayland? It is the only open question
   that could change the design, so it is answered before anything is
   built on it.
2. **Application shell and the Manual page** — self-contained, no dconf
   writes; proves the window, the theming and the keyboard model.
3. **Menu page** — the four action behaviours and the theme gallery.
4. **Keybindings editor** — largest surface and highest risk, best
   attempted once the rest is solid.

## Explicitly not in scope

- Creating arbitrary new custom keybindings (GNOME Settings does this).
- Replacing `gnomarchy-keymap` or duplicating its default layouts.
- Application launching; the GNOME Overview covers it, which is the same
  division of labour `bin/gnomarchy-menu` already states in its header.
- A Markdown renderer beyond the subset the manual measurably uses.
