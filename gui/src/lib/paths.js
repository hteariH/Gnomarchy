// Where the repository is, and small file helpers over Gio.
//
// GNOMARCHY_PATH is honoured when set (the installer and the CLI both export
// it); otherwise it is derived from this file's own location, so the app runs
// from a checkout without any environment at all.

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

function repoRoot() {
  const fromEnv = GLib.getenv('GNOMARCHY_PATH');
  if (fromEnv !== null && fromEnv !== '') return fromEnv;
  // .../gui/src/lib/paths.js -> up four levels
  const here = Gio.File.new_for_uri(import.meta.url);
  return here.get_parent().get_parent().get_parent().get_parent().get_path();
}

export const GNOMARCHY_PATH = repoRoot();

export function dataFile(name) {
  return GLib.build_filenamev([GNOMARCHY_PATH, 'gui', 'data', name]);
}

// Returns null when the file is absent, which several callers treat as "not
// configured yet" rather than an error. Any other failure is left to throw.
export function readTextFile(path) {
  const file = Gio.File.new_for_path(path);
  if (!file.query_exists(null)) return null;
  const [, bytes] = file.load_contents(null);
  return new TextDecoder().decode(bytes);
}

export function listDir(path) {
  const dir = Gio.File.new_for_path(path);
  if (!dir.query_exists(null)) return [];
  const names = [];
  const iter = dir.enumerate_children('standard::name', Gio.FileQueryInfoFlags.NONE, null);
  let info;
  while ((info = iter.next_file(null)) !== null) names.push(info.get_name());
  return names.sort();
}
