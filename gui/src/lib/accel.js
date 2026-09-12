// Accelerator strings, as GNOME stores them in dconf: "<Super><Shift>k".
//
// Pure string functions with no gi:// imports, so they run under Node in CI
// and under GJS in the app. The bash original could only format; this can
// also compare and validate, which the editable keybindings page needs.

export const MOD_ORDER = ['Control', 'Alt', 'Shift', 'Super'];

const MOD_ALIASES = { Primary: 'Control', Ctrl: 'Control', Meta: 'Super' };
const MOD_LABELS = { Control: 'Ctrl', Alt: 'Alt', Shift: 'Shift', Super: 'Super' };

// "<Super><Shift>k" -> { mods: ['Super', 'Shift'], key: 'k' }
//
// Modifiers come back in the order they were written. That matters: display
// follows the written order (so a binding the user knows as Super+Shift+H is
// shown that way, as the bash version showed it), while comparison uses the
// canonical order that normalizeAccel imposes.
export function parseAccel(str) {
  if (typeof str !== 'string') return null;
  const raw = str.trim();
  // The empty forms dconf reports for an unbound key.
  if (raw === '' || raw === '[]' || raw.startsWith('@as')) return null;

  const mods = [];
  let rest = raw;
  const modRe = /^<([A-Za-z0-9]+)>/;
  let m;
  while ((m = modRe.exec(rest)) !== null) {
    const name = MOD_ALIASES[m[1]] ?? m[1];
    if (!MOD_ORDER.includes(name)) return null;
    if (!mods.includes(name)) mods.push(name);
    rest = rest.slice(m[0].length);
  }

  // A modifier with nothing after it is not an accelerator.
  if (rest === '') return null;
  // Anything still containing angle brackets was malformed.
  if (rest.includes('<') || rest.includes('>')) return null;

  return { mods, key: rest };
}

// Canonical form, for storage and for equality comparison only -- never for
// display. Two spellings of the same shortcut must produce one string here.
export function normalizeAccel(str) {
  const parsed = parseAccel(str);
  if (parsed === null) return null;
  // Single printable characters are lowercased so <Super>K and <Super>k are one
  // binding; named keys (Left, F11, BackSpace) keep their capitalisation
  // because GNOME's keysym names are case-significant.
  const key = parsed.key.length === 1 ? parsed.key.toLowerCase() : parsed.key;
  const ordered = MOD_ORDER.filter((name) => parsed.mods.includes(name));
  return ordered.map((name) => `<${name}>`).join('') + key;
}

export function formatAccel(str) {
  const parsed = parseAccel(str);
  if (parsed === null) return '';
  const key = parsed.key.length === 1
    ? parsed.key.toUpperCase()
    : parsed.key.charAt(0).toUpperCase() + parsed.key.slice(1);
  return [...parsed.mods.map((name) => MOD_LABELS[name]), key].join(' + ');
}

export function isValidAccel(str) {
  const parsed = parseAccel(str);
  if (parsed === null) return false;
  // An unmodified printable key would swallow ordinary typing. Named keys
  // (F11, Print, XF86AudioPlay) are fine on their own, as they are in GNOME
  // Settings.
  if (parsed.mods.length === 0 && parsed.key.length === 1) return false;
  return true;
}
