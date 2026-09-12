// Every keybinding actually in effect, read through Gio.Settings.
//
// The bash original parsed the output of `gsettings` and had to special-case
// "@as []" by hand (bin/gnomarchy-keybindings:36). Typed access removes that,
// and -- unlike string parsing -- it can also write, which the editor needs.

import Gio from 'gi://Gio';

import { normalizeAccel } from './accel.js';

const MEDIA_KEYS = 'org.gnome.settings-daemon.plugins.media-keys';
const CUSTOM_SCHEMA = `${MEDIA_KEYS}.custom-keybinding`;
// Forge drives dynamic tiling; Tiling Shell (manual mode, the default) still
// ships alongside it. Tactile is gone from the distribution entirely.
const FORGE_KEYS = 'org.gnome.shell.extensions.forge.keybindings';
const TILING_SHELL = 'org.gnome.shell.extensions.tilingshell';

const SCHEMA_SECTIONS = [
  ['org.gnome.desktop.wm.keybindings', 'Windows & Workspaces'],
  ['org.gnome.shell.keybindings', 'Shell'],
  ['org.gnome.mutter.keybindings', 'Mutter'],
];

// Mirrors bin/gnomarchy-keybindings:dump_tiling()'s `case` block verbatim.
const FORGE_LABELS = {
  'window-focus-left': 'Focus window left',
  'window-focus-down': 'Focus window down',
  'window-focus-up': 'Focus window up',
  'window-focus-right': 'Focus window right',
  'window-move-left': 'Move window left in the tree',
  'window-move-down': 'Move window down in the tree',
  'window-move-up': 'Move window up in the tree',
  'window-move-right': 'Move window right in the tree',
  'window-swap-left': 'Swap window with the one left',
  'window-swap-down': 'Swap window with the one down',
  'window-swap-up': 'Swap window with the one up',
  'window-swap-right': 'Swap window with the one right',
  'window-toggle-float': 'Float the focused window',
  'window-toggle-always-float': 'Always float this window',
  'con-split-layout-toggle': 'Flip the split direction',
  'con-tabbed-layout-toggle': 'Tabbed layout for this container',
  'con-stacked-layout-toggle': 'Stacked layout for this container',
  'window-expand': 'Expand the focused window',
  'window-shrink': 'Shrink the focused window',
  'window-reset-sizes': 'Reset every window to an even split',
  'window-gap-size-increase': 'Increase the gap',
  'window-gap-size-decrease': 'Decrease the gap',
  'prefs-tiling-toggle': 'Suspend or resume tiling',
};
// Order matches the `for key in ...` loop in dump_tiling().
const FORGE_KEY_ORDER = [
  'window-focus-left', 'window-focus-down', 'window-focus-up', 'window-focus-right',
  'window-move-left', 'window-move-down', 'window-move-up', 'window-move-right',
  'window-swap-left', 'window-swap-down', 'window-swap-up', 'window-swap-right',
  'window-toggle-float', 'window-toggle-always-float', 'con-split-layout-toggle',
  'con-tabbed-layout-toggle', 'con-stacked-layout-toggle',
  'window-expand', 'window-shrink', 'window-reset-sizes',
  'window-gap-size-increase', 'window-gap-size-decrease', 'prefs-tiling-toggle',
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
// for Forge and Tiling Shell, whose case blocks in bin/gnomarchy-keybindings
// list keys in a deliberate (non-alphabetical) order. Without it, keys come
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

// Forge's bindings only apply in dynamic tiling mode.
function forgeEnabled() {
  if (!schemaExists('org.gnome.shell') || !schemaExists(FORGE_KEYS)) return false;
  const shell = new Gio.Settings({ schemaId: 'org.gnome.shell' });
  return shell.get_strv('enabled-extensions').some((name) => name.includes('forge@jmmaranan.com'));
}

// Tiling Shell's bindings only apply in manual tiling mode, which is the
// default. Its auto-placement is deliberately off there; dynamic mode is Forge.
function tilingShellEnabled() {
  if (!schemaExists('org.gnome.shell') || !schemaExists(TILING_SHELL)) return false;
  const shell = new Gio.Settings({ schemaId: 'org.gnome.shell' });
  return shell.get_strv('enabled-extensions').some((name) => name.includes('tilingshell'));
}

// Section order mirrors collect() in bin/gnomarchy-keybindings exactly, since
// the page renders sections in array order: custom slots, Forge, the three
// desktop/shell/mutter schemas, then Tiling Shell last.
export function readBindings() {
  const bindings = [...readCustomSlots()];

  if (forgeEnabled()) {
    bindings.push(...readStrvSchema(
      FORGE_KEYS, 'Dynamic Tiling',
      null,
      (key) => FORGE_LABELS[key],
      FORGE_KEY_ORDER,
    ));
  }

  for (const [schemaId, section] of SCHEMA_SECTIONS) {
    bindings.push(...readStrvSchema(schemaId, section, null, null));
  }

  if (tilingShellEnabled()) {
    bindings.push(...readStrvSchema(
      TILING_SHELL, 'Manual Tiling',
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
  const watched = [MEDIA_KEYS, FORGE_KEYS, TILING_SHELL, ...SCHEMA_SECTIONS.map(([id]) => id)];
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
