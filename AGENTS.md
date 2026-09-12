## The control center GUI

`gui/` is a GTK4/libadwaita application written in GJS, run directly with
`gjs -m gui/src/main.js --page=<menu|keybindings|manual>` — there is no build
step and no transpilation. `bin/gnomarchy-menu`, `bin/gnomarchy-keybindings`
and `bin/gnomarchy-manual` launch it and fall back to their old text paths
when there is no display or no `gjs`.

`gui/src/lib/` splits into two kinds of module. The ones with a unit test in
`gui/tests/` — `accel.js`, `conflicts.js`, `markdown.js`, `themes.js`,
`manual.js` — are pure functions with **no `gi://` import**, so they also run
under plain Node (`node --test gui/tests/*.test.js`). Keep it that way: an
import from GObject introspection in one of those files makes the test suite
unrunnable outside a GJS session. `actions.js`, `keysources.js` and `paths.js`
talk to Gio.Settings directly and are GJS-only by necessity.

`gui/` must never move under `bin/` — `install/config/symlinks.sh` publishes
everything directly under `bin/` into `/usr/local/bin` as a command, and
`gui/` is a source tree, not a subcommand.
