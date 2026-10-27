// Every keybinding actually in effect, read through Gio.Settings.
//
// The bash original parsed the output of `gsettings` and had to special-case
// "@as []" by hand (bin/gnomarchy-keybindings:36). Typed access removes that,
// and -- unlike string parsing -- it can also write, which the editor needs.

import Gio from 'gi://Gio';

import { normalizeAccel } from './accel.js';

const MEDIA_KEYS = 'org.gnome.settings-daemon.plugins.media-keys';
const CUSTOM_SCHEMA = `${MEDIA_KEYS}.custom-keybinding`;
// Tiling Shell is the only tiling extension Gnomarchy ships.
const TILING_SHELL = 'org.gnome.shell.extensions.tilingshell';

const SCHEMA_SECTIONS = [
  ['org.gnome.desktop.wm.keybindings', 'Windows & Workspaces'],
  ['org.gnome.shell.keybindings', 'Shell'],
  ['org.gnome.mutter.keybindings', 'Mutter'],
];

// Mirrors bin/gnomarchy-keybindings:dump_manual_tiling()'s `case` block.
const TILING_SHELL_LABELS = {
  'move-window-left': 'Throw the window into the tile left',
  'move-window-down': 'Throw the window into the tile down',
  'move-window-up': 'Throw the window into the tile up',
  'move-window-right': 'Throw the window into the tile right',
  'untile-window': 'Untile, back to the original size',
  'cycle-layouts': 'Cycle the zone layout',
};

const source = Gio.SettingsSchemaSource.get_default();

function schemaExists(id) {
  return source.lookup(id, true) !== null;
}

function readCustomSlots() {
  if (!schemaExists(MEDIA_KEYS)) return [];
  const mediaKeys = new Gio.Settings({ schemaId: MEDIA_KEYS });
  const bindings = [];

  for (const path of mediaKeys.get_strv('custom-keybindings')) {
    const slot = Gio.Settings.new_with_path(CUSTOM_SCHEMA, path);
    const accel = normalizeAccel(slot.get_string('binding'));
    if (accel === null) continue;
    const name = slot.get_string('name');
    const command = slot.get_string('command');
    bindings.push({
      id: `custom:${path}`,
      section: 'Gnomarchy Commands',
      accel,
      description: name === '' ? command : name,
      kind: 'custom',
      schemaId: CUSTOM_SCHEMA,
      key: 'binding',
      path,
    });
  }
  return bindings;
}

// `keyOrder`, when given, both restricts and orders the keys read -- needed
// for Tiling Shell, whose case block in bin/gnomarchy-keybindings lists keys
// in a deliberate (non-alphabetical) order. Without it, keys come
// from the schema itself, sorted, matching dump_schema()'s `sort`.
function readStrvSchema(schemaId, section, keyFilter, labelFor, keyOrder = null) {
  if (!schemaExists(schemaId)) return [];
  const schema = source.lookup(schemaId, true);
  const settings = new Gio.Settings({ schemaId });
  const bindings = [];

  const keys = keyOrder !== null ? keyOrder : schema.list_keys().sort();

  for (const key of keys) {
    if (keyOrder !== null && !schema.has_key(key)) continue;
    if (keyFilter !== null && !keyFilter(key)) continue;

    const schemaKey = schema.get_key(key);
    // Only string-array keys are accelerators; skip booleans and the rest.
    if (schemaKey.get_value_type().dup_string() !== 'as') continue;

    const values = settings.get_strv(key);
    if (values.length === 0) continue;
    // Alternates are noise in a list this long; the first is the binding
    // people mean, which is what the bash version showed too.
    const accel = normalizeAccel(values[0]);
    if (accel === null) continue;

    const summary = schemaKey.get_summary();
    bindings.push({
      id: `${schemaId}:${key}`,
      section,
      accel,
      description: labelFor !== null ? labelFor(key) : (summary === null ? key : summary),
      kind: 'strv',
      schemaId,
      key,
      path: null,
    });
  }
  return bindings;
}

// Tiling Shell's bindings only apply while it is enabled.
function tilingShellEnabled() {
  if (!schemaExists('org.gnome.shell') || !schemaExists(TILING_SHELL)) return false;
  const shell = new Gio.Settings({ schemaId: 'org.gnome.shell' });
  return shell.get_strv('enabled-extensions').some((name) => name.includes('tilingshell'));
}

// Section order mirrors collect() in bin/gnomarchy-keybindings exactly, since
// the page renders sections in array order: custom slots, the three
// desktop/shell/mutter schemas, then Tiling Shell last.
export function readBindings() {
  const bindings = [...readCustomSlots()];

  for (const [schemaId, section] of SCHEMA_SECTIONS) {
    bindings.push(...readStrvSchema(schemaId, section, null, null));
  }

  if (tilingShellEnabled()) {
    bindings.push(...readStrvSchema(
      TILING_SHELL, 'Tiling',
      null,
      (key) => TILING_SHELL_LABELS[key],
      Object.keys(TILING_SHELL_LABELS),
    ));
  }

  return bindings;
}

export function writeBinding(binding, accel) {
  if (binding.kind === 'custom') {
    Gio.Settings.new_with_path(binding.schemaId, binding.path).set_string(binding.key, accel);
    return;
  }
  const settings = new Gio.Settings({ schemaId: binding.schemaId });
  settings.set_strv(binding.key, accel === '' ? [] : [accel]);
}

export function onBindingsChanged(callback) {
  const watched = [MEDIA_KEYS, TILING_SHELL, ...SCHEMA_SECTIONS.map(([id]) => id)];
  // Held on the module so the Settings objects outlive this call; without a
  // reference they are collected and the signal never fires again.
  onBindingsChanged._settings ??= [];
  for (const schemaId of watched) {
    if (!schemaExists(schemaId)) continue;
    const settings = new Gio.Settings({ schemaId });
    settings.connect('changed', () => callback());
    onBindingsChanged._settings.push(settings);
  }
}

export { findConflict } from './conflicts.js';
