# Gnomarchy Control Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the three terminal UIs (`gnomarchy menu`, `gnomarchy keybindings`, `gnomarchy manual`) with one keyboard-driven GTK4/libadwaita application written in GJS, keeping the bash commands as a non-interactive fallback.

**Architecture:** A single `Adw.Application` (`org.gnomarchy.ControlCenter`) presenting an `Adw.NavigationSplitView` with three pages. Logic that can be expressed over strings lives in `gui/src/lib/*.js` as pure ES modules with no `gi://` imports, so it is unit-testable under Node on any host; everything touching GTK, dconf or subprocesses lives in `gui/src/pages/*.js` and the GI-backed libs. The three existing `bin/` scripts stay the entry points and gain a `--page=` dispatch to the app.

**Tech Stack:** GJS (ES modules, `gjs -m`), GTK 4, libadwaita 1, `Gio.Settings` for dconf, `Gio.Subprocess` for actions, Node's built-in `node:test` runner for the pure-module unit tests, bash for entry points/install/migration/CI.

**Spec:** `docs/superpowers/specs/2026-09-12-control-center-gui-design.md` — read it before starting. This plan argues from that spec; where the two differ, the deviation is called out explicitly in the task.

## Global Constraints

Copied verbatim from `CLAUDE.md` and the spec. Every task's requirements implicitly include this section.

- Bash: `#!/bin/bash`, `[[ ]]` for strings, `(( ))` for arithmetic, `$HOME` never a hardcoded path.
- Bash presentation helpers come from `install/helpers/presentation.sh`: `gnomarchy_header`, `gnomarchy_step`, `gnomarchy_warn`, `gnomarchy_error`, `gnomarchy_substep`. `gnomarchy_error` only prints — add an explicit `exit` if you mean to stop.
- **Do not suppress errors by default.** No `2>/dev/null` or `|| true` unless failure genuinely does not matter, and say so in a comment. Five shipped defects came from this.
- Package names must be verified against the real databases before being added: `curl -sSL "https://archlinux.org/packages/search/json/?name=<pkg>"`. `install/gnomarchy-base.packages` holds official-repo packages only.
- Migrations live at `migrations/<YYYY-MM-DD-HHMM>-<slug>.sh` and **must be idempotent** — they may run on a machine in any prior state.
- New scripts created on this Windows host land in git as mode 100644. Run `git update-index --chmod=+x <file>` on any new bash script, or the installer's `chmod +x` dirties the tree and blocks the next `git pull`.
- Anything under `bin/gnomarchy*` is symlinked into `/usr/local/bin` by `install/config/symlinks.sh:26`. Application modules therefore must **not** live in `bin/`.
- Documentation is a claim about the code. `README.md`, `AGENTS.md` and the relevant `manual/` page change in the same commit as the behaviour.
- **Pure modules (`gui/src/lib/accel.js`, `markdown.js`, `themes.js`) must not import `gi://` anything.** That is what makes them testable under Node. A `gi://` import in one of these files is a defect even if the app still runs.
- GJS application id, fixed for the life of the app: `org.gnomarchy.ControlCenter`.
- Canonical modifier order, used for **normalisation and comparison only**: `Control`, `Alt`, `Shift`, `Super`. `<Primary>` is a synonym for `<Control>` and is normalised away. **Display preserves the order the binding was written in**, so a shortcut the user knows as `Super + Shift + H` is never shown as `Shift + Super + H`; `bin/gnomarchy-keybindings` behaves this way today and the GUI must not regress it.

## Environment

Local development and testing uses the Ubuntu WSL instance, which has GTK 4 and a WSLg Wayland display already. One-time setup (already run; re-run if a task cannot find `gjs`):

```bash
wsl -d Ubuntu -e bash -lc 'sudo apt-get update && sudo apt-get install -y gjs gir1.2-adw-1 gir1.2-gtk-4.0'
```

The repository is reachable inside WSL at `/mnt/c/Users/aberk/claude/Gnomarchy/.claude/worktrees/gnomarchy-gui-keyboard-c573cf`. Throughout this plan that path is written as `$REPO`; export it first:

```bash
wsl -d Ubuntu -e bash -lc 'export REPO=/mnt/c/Users/aberk/claude/Gnomarchy/.claude/worktrees/gnomarchy-gui-keyboard-c573cf; cd $REPO && pwd'
```

**Two honest limits on WSL, which decide what it can and cannot prove:**

1. WSL ships libadwaita 1.5; Arch/GNOME 50 ships 1.7+. Every API this plan uses exists in 1.5 (`Adw.NavigationSplitView` ≥1.4, `Adw.NavigationView` ≥1.4, `Adw.AlertDialog` ≥1.5), so WSL is a valid smoke test — but CI against the real ISO has the final say.
2. **WSLg runs Weston, not mutter.** It therefore cannot answer whether GNOME's compositor grabs `Super+Q` before the app sees it. Task 8 is designed so that question does not block anything (see the deviation note there).

Node is on the Windows host (v26) and runs the pure-module tests directly:

```bash
node --test gui/tests/
```

---

### Task 1: Accelerator library (pure)

Replaces the string-mangling in `bin/gnomarchy-keybindings:36-60` with tested functions. Everything the Keybindings page does about key *names* — display, comparison, validation — lives here and nowhere else.

**Files:**
- Create: `gui/src/lib/accel.js`
- Test: `gui/tests/accel.test.js`

**Interfaces:**
- Consumes: nothing.
- Produces, all pure and `gi://`-free:
  - `parseAccel(str) -> {mods: string[], key: string} | null` — `mods` in canonical order.
  - `normalizeAccel(str) -> string | null` — e.g. `'<Primary><Super>Q'` → `'<Control><Super>q'`.
  - `formatAccel(str) -> string` — e.g. `'<Super><Shift>k'` → `'Super + Shift + K'`; `''` for unbindable input.
  - `isValidAccel(str) -> boolean` — false for bare modifiers and for unmodified single printable keys.
  - `MOD_ORDER: string[]` — `['Control', 'Alt', 'Shift', 'Super']`.

- [ ] **Step 1: Write the failing test**

Create `gui/tests/accel.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseAccel, normalizeAccel, formatAccel, isValidAccel } from '../src/lib/accel.js';

test('parseAccel splits modifiers from the key, preserving written order', () => {
  assert.deepEqual(parseAccel('<Super><Shift>k'), { mods: ['Super', 'Shift'], key: 'k' });
  assert.deepEqual(parseAccel('<Super>space'), { mods: ['Super'], key: 'space' });
});

test('parseAccel treats Primary as Control', () => {
  assert.deepEqual(parseAccel('<Primary><Alt>Delete'), { mods: ['Control', 'Alt'], key: 'Delete' });
  assert.deepEqual(parseAccel('<Super><Control>x'), { mods: ['Super', 'Control'], key: 'x' });
});

test('parseAccel rejects the empty dconf forms', () => {
  for (const raw of ['', '@as []', '[]', '<Super>']) assert.equal(parseAccel(raw), null);
});

test('normalizeAccel makes equal bindings compare equal', () => {
  assert.equal(normalizeAccel('<Super><Shift>K'), normalizeAccel('<Shift><Super>k'));
  assert.equal(normalizeAccel('<Primary>c'), '<Control>c');
});

test('normalizeAccel reorders modifiers canonically, unlike formatAccel', () => {
  assert.equal(normalizeAccel('<Super><Shift>k'), '<Shift><Super>k');
  assert.equal(formatAccel('<Super><Shift>k'), 'Super + Shift + K');
});

test('normalizeAccel preserves named keys verbatim', () => {
  assert.equal(normalizeAccel('<Super>Left'), '<Super>Left');
  assert.equal(normalizeAccel('<Super>BackSpace'), '<Super>BackSpace');
});

test('formatAccel renders for humans and capitalises the trailing key', () => {
  assert.equal(formatAccel('<Super><Shift>h'), 'Super + Shift + H');
  assert.equal(formatAccel('<Super><Alt>space'), 'Super + Alt + Space');
  assert.equal(formatAccel('<Primary><Alt>Delete'), 'Ctrl + Alt + Delete');
  assert.equal(formatAccel('@as []'), '');
});

test('isValidAccel rejects bare modifiers and unmodified printables', () => {
  assert.equal(isValidAccel('<Super>'), false);
  assert.equal(isValidAccel('q'), false);
  assert.equal(isValidAccel('<Super>q'), true);
  assert.equal(isValidAccel('F11'), true);
  assert.equal(isValidAccel('<Shift>F11'), true);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test gui/tests/accel.test.js`
Expected: FAIL — `Cannot find module '../src/lib/accel.js'`.

- [ ] **Step 3: Write minimal implementation**

Create `gui/src/lib/accel.js`:

```js
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test gui/tests/accel.test.js`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add gui/src/lib/accel.js gui/tests/accel.test.js
git commit -m "feat(gui): add tested accelerator parsing, formatting and validation"
```

---

### Task 2: Markdown library (pure)

Renders the manual to Pango markup, and reports constructs it cannot render so CI can refuse them.

**Files:**
- Create: `gui/src/lib/markdown.js`
- Test: `gui/tests/markdown.test.js`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `renderBlocks(md) -> Array<{type, markup}>` where `type` is one of `h1 h2 h3 p code ul ol`. `markup` is Pango-safe markup; for `ul`/`ol` it is one line per item, already bulleted/numbered.
  - `unsupported(md) -> Array<{line: number, kind: string}>` — `kind` is one of `table link image blockquote`. Line numbers are 1-based.
  - `escapePango(text) -> string`.

- [ ] **Step 1: Write the failing test**

Create `gui/tests/markdown.test.js`:

````js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderBlocks, unsupported, escapePango } from '../src/lib/markdown.js';

test('escapePango escapes the three markup characters', () => {
  assert.equal(escapePango('a & b < c > d'), 'a &amp; b &lt; c &gt; d');
});

test('renderBlocks classifies the heading levels', () => {
  const blocks = renderBlocks('# One\n\n## Two\n\n### Three\n');
  assert.deepEqual(blocks.map((b) => b.type), ['h1', 'h2', 'h3']);
  assert.equal(blocks[0].markup, 'One');
});

test('renderBlocks joins wrapped paragraph lines into one block', () => {
  const blocks = renderBlocks('alpha\nbeta\n\ngamma\n');
  assert.deepEqual(blocks, [
    { type: 'p', markup: 'alpha beta' },
    { type: 'p', markup: 'gamma' },
  ]);
});

test('renderBlocks keeps fenced code verbatim and unformatted', () => {
  const blocks = renderBlocks('```bash\ngnomarchy update\na **b** `c`\n```\n');
  assert.deepEqual(blocks, [
    { type: 'code', markup: 'gnomarchy update\na **b** `c`' },
  ]);
});

test('renderBlocks applies inline bold, italic and code', () => {
  const [block] = renderBlocks('a **b** and *i* and `c`\n');
  assert.equal(block.markup, 'a <b>b</b> and <i>i</i> and <tt>c</tt>');
});

test('renderBlocks escapes before applying inline markup', () => {
  const [block] = renderBlocks('use `<Super>k` & go\n');
  assert.equal(block.markup, 'use <tt>&lt;Super&gt;k</tt> &amp; go');
});

test('renderBlocks does not format inside inline code', () => {
  const [block] = renderBlocks('literal `a **b** c`\n');
  assert.equal(block.markup, 'literal <tt>a **b** c</tt>');
});

test('renderBlocks collects list items into one block', () => {
  const blocks = renderBlocks('- one\n- two\n\n1. first\n2. second\n');
  assert.deepEqual(blocks, [
    { type: 'ul', markup: '• one\n• two' },
    { type: 'ol', markup: '1. first\n2. second' },
  ]);
});

test('unsupported reports constructs the renderer cannot show', () => {
  const md = 'fine\n\n| a | b |\n\n> quote\n\n[text](url)\n\n![alt](img)\n';
  assert.deepEqual(unsupported(md), [
    { line: 3, kind: 'table' },
    { line: 5, kind: 'blockquote' },
    { line: 7, kind: 'link' },
    { line: 9, kind: 'image' },
  ]);
});

test('unsupported ignores anything inside a fenced code block', () => {
  assert.deepEqual(unsupported('```\n| a | b |\n> not a quote\n```\n'), []);
});

test('unsupported is empty for a document using only the supported subset', () => {
  const md = '# T\n\n## S\n\npara **b** `c`\n\n- item\n\n```\ncode\n```\n';
  assert.deepEqual(unsupported(md), []);
});
````

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test gui/tests/markdown.test.js`
Expected: FAIL — `Cannot find module '../src/lib/markdown.js'`.

- [ ] **Step 3: Write minimal implementation**

Create `gui/src/lib/markdown.js`:

````js
// Markdown -> Pango markup, for the manual pages only.
//
// The supported subset is not a guess: across the 17 pages there are 17 '#',
// 60 '##', 2 '###', 26 fenced code blocks, 41 list items, 20 bold spans and
// 121 inline code spans, and zero tables, links, images or blockquotes.
// unsupported() lets CI keep it that way, so a page that grows a table fails
// the build instead of rendering as "| a | b |".
//
// Pure: no gi:// imports, so this runs under Node in the unit tests.

export function escapePango(text) {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Inline code is extracted before any other formatting so that markdown
// characters inside it stay literal, then restored at the end. The
// placeholders use Unicode private-use characters, which cannot occur in a
// manual page, so no real text can be mistaken for one.
const CODE_OPEN = '\uE000';
const CODE_CLOSE = '\uE001';
const CODE_PLACEHOLDER = new RegExp(`${CODE_OPEN}(\\d+)${CODE_CLOSE}`, 'g');

function inline(text) {
  const codes = [];
  const withPlaceholders = text.replace(/`([^`]*)`/g, (_, code) => {
    codes.push(code);
    return `${CODE_OPEN}${codes.length - 1}${CODE_CLOSE}`;
  });

  const out = escapePango(withPlaceholders)
    .replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>')
    .replace(/(^|[^*])\*([^*]+)\*/g, '$1<i>$2</i>');

  return out.replace(CODE_PLACEHOLDER, (_, i) => `<tt>${escapePango(codes[Number(i)])}</tt>`);
}

export function renderBlocks(md) {
  const lines = md.split('\n');
  const blocks = [];

  let paragraph = [];
  let list = null; // { type: 'ul' | 'ol', items: string[] }
  let fence = null; // string[] while inside a fenced block

  const flushParagraph = () => {
    if (paragraph.length > 0) {
      blocks.push({ type: 'p', markup: inline(paragraph.join(' ')) });
      paragraph = [];
    }
  };
  const flushList = () => {
    if (list !== null) {
      blocks.push({ type: list.type, markup: list.items.join('\n') });
      list = null;
    }
  };
  const flushAll = () => { flushParagraph(); flushList(); };

  for (const line of lines) {
    if (fence !== null) {
      if (line.startsWith('```')) {
        blocks.push({ type: 'code', markup: escapePango(fence.join('\n')) });
        fence = null;
      } else {
        fence.push(line);
      }
      continue;
    }

    if (line.startsWith('```')) { flushAll(); fence = []; continue; }

    if (line.trim() === '') { flushAll(); continue; }

    const heading = /^(#{1,3})\s+(.*)$/.exec(line);
    if (heading !== null) {
      flushAll();
      blocks.push({ type: `h${heading[1].length}`, markup: inline(heading[2].trim()) });
      continue;
    }

    const bullet = /^[-*]\s+(.*)$/.exec(line);
    if (bullet !== null) {
      flushParagraph();
      if (list === null || list.type !== 'ul') { flushList(); list = { type: 'ul', items: [] }; }
      list.items.push(`• ${inline(bullet[1])}`);
      continue;
    }

    const numbered = /^(\d+)\.\s+(.*)$/.exec(line);
    if (numbered !== null) {
      flushParagraph();
      if (list === null || list.type !== 'ol') { flushList(); list = { type: 'ol', items: [] }; }
      list.items.push(`${numbered[1]}. ${inline(numbered[2])}`);
      continue;
    }

    flushList();
    paragraph.push(line.trim());
  }

  if (fence !== null) blocks.push({ type: 'code', markup: escapePango(fence.join('\n')) });
  flushAll();
  return blocks;
}

export function unsupported(md) {
  const found = [];
  let inFence = false;

  md.split('\n').forEach((line, index) => {
    if (line.startsWith('```')) { inFence = !inFence; return; }
    if (inFence) return;

    const at = (kind) => found.push({ line: index + 1, kind });

    if (/^\s*\|.*\|\s*$/.test(line)) at('table');
    else if (/^\s*>/.test(line)) at('blockquote');
    else if (/!\[[^\]]*\]\([^)]*\)/.test(line)) at('image');
    else if (/\[[^\]]*\]\([^)]*\)/.test(line)) at('link');
  });

  return found;
}
````

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test gui/tests/markdown.test.js`
Expected: PASS, 10 tests.

- [ ] **Step 5: Prove it against the real manual**

Run: `node -e "import('./gui/src/lib/markdown.js').then(async (m)=>{const fs=await import('node:fs');let bad=0;for(const f of fs.readdirSync('manual')){const u=m.unsupported(fs.readFileSync('manual/'+f,'utf8'));if(u.length){bad++;console.log(f,u);}}console.log(bad===0?'OK: manual is within the supported subset':'FAIL');})"`
Expected: `OK: manual is within the supported subset`. If a page reports something, that is a real finding — fix the plan's subset or the page, do not weaken the checker silently.

- [ ] **Step 6: Commit**

```bash
git add gui/src/lib/markdown.js gui/tests/markdown.test.js
git commit -m "feat(gui): render the manual's markdown subset to Pango markup"
```

---

### Task 3: Theme palette library (pure)

Feeds the Menu page's theme gallery. `themes/<name>/alacritty.toml` is the canonical palette per `CLAUDE.md`.

**Files:**
- Create: `gui/src/lib/themes.js`
- Test: `gui/tests/themes.test.js`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `parsePalette(tomlText) -> {background, foreground, normal: {black,red,green,yellow,blue,magenta,cyan,white}} | null` — `null` when `[colors.primary]` background/foreground are absent.
  - `swatchColors(palette) -> string[]` — eight hex strings, in the order black…white, for the card's colour strip.
  - `prettyThemeName(dirName) -> string` — `'tokyo-night'` → `'Tokyo Night'`.

- [ ] **Step 1: Write the failing test**

Create `gui/tests/themes.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parsePalette, swatchColors, prettyThemeName } from '../src/lib/themes.js';

const SAMPLE = `[colors.primary]
background = "#1a1b26"
foreground = "#c0caf5"

[colors.normal]
black   = "#15161e"
red     = "#f7768e"
green   = "#9ece6a"
yellow  = "#e0af68"
blue    = "#7aa2f7"
magenta = "#bb9af7"
cyan    = "#7dcfff"
white   = "#a9b1d6"

[colors.bright]
black   = "#414868"
red     = "#ff0000"
`;

test('parsePalette reads primary and normal colours', () => {
  const palette = parsePalette(SAMPLE);
  assert.equal(palette.background, '#1a1b26');
  assert.equal(palette.foreground, '#c0caf5');
  assert.equal(palette.normal.red, '#f7768e');
  assert.equal(palette.normal.white, '#a9b1d6');
});

test('parsePalette does not let [colors.bright] overwrite [colors.normal]', () => {
  assert.equal(parsePalette(SAMPLE).normal.red, '#f7768e');
});

test('parsePalette returns null without a usable primary section', () => {
  assert.equal(parsePalette('[colors.normal]\nred = "#ff0000"\n'), null);
});

test('swatchColors returns the eight normal colours in order', () => {
  assert.deepEqual(swatchColors(parsePalette(SAMPLE)), [
    '#15161e', '#f7768e', '#9ece6a', '#e0af68',
    '#7aa2f7', '#bb9af7', '#7dcfff', '#a9b1d6',
  ]);
});

test('swatchColors falls back to the foreground for a missing colour', () => {
  const palette = parsePalette('[colors.primary]\nbackground = "#000000"\nforeground = "#ffffff"\n');
  assert.deepEqual(swatchColors(palette), Array(8).fill('#ffffff'));
});

test('prettyThemeName turns a directory name into a label', () => {
  assert.equal(prettyThemeName('tokyo-night'), 'Tokyo Night');
  assert.equal(prettyThemeName('nord'), 'Nord');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test gui/tests/themes.test.js`
Expected: FAIL — `Cannot find module '../src/lib/themes.js'`.

- [ ] **Step 3: Write minimal implementation**

Create `gui/src/lib/themes.js`:

```js
// Palettes for the theme gallery, read from each theme's alacritty.toml --
// the canonical palette per CLAUDE.md, and the same file the GTK CSS and the
// GNOME Terminal profile are generated from.
//
// This is a reader for the shape those files actually have (section headers
// and `key = "#hex"` lines), not a TOML parser. Pure: no gi:// imports.

const NORMAL_KEYS = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white'];

export function parsePalette(tomlText) {
  let section = '';
  const primary = {};
  const normal = {};

  for (const line of tomlText.split('\n')) {
    const trimmed = line.trim();
    if (trimmed === '' || trimmed.startsWith('#')) continue;

    const header = /^\[([^\]]+)\]$/.exec(trimmed);
    if (header !== null) { section = header[1]; continue; }

    const pair = /^([A-Za-z_]+)\s*=\s*"([^"]*)"$/.exec(trimmed);
    if (pair === null) continue;

    // Only these two sections are read; [colors.bright] and the rest are
    // deliberately ignored so they cannot overwrite the normal palette.
    if (section === 'colors.primary') primary[pair[1]] = pair[2];
    else if (section === 'colors.normal') normal[pair[1]] = pair[2];
  }

  if (primary.background === undefined || primary.foreground === undefined) return null;

  const filled = {};
  for (const key of NORMAL_KEYS) filled[key] = normal[key] ?? primary.foreground;

  return { background: primary.background, foreground: primary.foreground, normal: filled };
}

export function swatchColors(palette) {
  return NORMAL_KEYS.map((key) => palette.normal[key]);
}

export function prettyThemeName(dirName) {
  return dirName
    .split('-')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test gui/tests/themes.test.js`
Expected: PASS, 6 tests.

- [ ] **Step 5: Prove it against every shipped theme**

Run: `node -e "import('./gui/src/lib/themes.js').then(async (m)=>{const fs=await import('node:fs');let n=0,bad=[];for(const d of fs.readdirSync('themes')){const p='themes/'+d+'/alacritty.toml';if(!fs.existsSync(p))continue;n++;if(m.parsePalette(fs.readFileSync(p,'utf8'))===null)bad.push(d);}console.log('parsed',n,'themes; failures:',bad);})"`
Expected: a non-zero count and `failures: []`. A theme that fails to parse is a real finding — report it rather than loosening the parser.

- [ ] **Step 6: Commit**

```bash
git add gui/src/lib/themes.js gui/tests/themes.test.js
git commit -m "feat(gui): parse theme palettes from the canonical alacritty.toml"
```

---

### Task 4: Application shell

The window, the sidebar, `--page=` routing, single-instance behaviour, the keyboard model and live re-theming. After this task the app runs and is navigable, with three placeholder pages.

**Files:**
- Create: `gui/src/main.js`, `gui/src/window.js`, `gui/src/lib/paths.js`, `gui/data/gnomarchy-gui.css`
- Test: manual, under WSL (see steps 5–7)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `gui/src/lib/paths.js`: `GNOMARCHY_PATH: string`, `dataFile(name) -> string`, `readTextFile(path) -> string | null`, `listDir(path) -> string[]`.
  - `gui/src/window.js`: `ControlWindow` — a `GObject`-registered `Adw.ApplicationWindow` subclass with `showPage(name)` where `name` is `'menu' | 'keybindings' | 'manual'`.
  - Each page module (Tasks 5–7) must export a class with a `widget` property (a `Gtk.Widget` for the content pane), a `focusSearch()` method, and an `escape()` method returning `true` when it consumed the key.

- [ ] **Step 1: Write the path helper**

Create `gui/src/lib/paths.js`:

```js
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
```

- [ ] **Step 2: Write the stylesheet**

Create `gui/data/gnomarchy-gui.css`. It carries only what the theme variables cannot express — the theme engine supplies every colour:

```css
/* Only structure. Colours come from ~/.config/gtk-4.0/gnomarchy-theme.css,
   which gnomarchy-theme-set generates and gtk.css imports. Nothing here may
   hardcode a colour, or switching themes would stop working. */

.gnomarchy-manual-body {
  padding: 12px 18px;
}

.gnomarchy-manual-body label {
  margin-bottom: 6px;
}

.gnomarchy-code {
  font-family: monospace;
  padding: 8px 10px;
  border-radius: 6px;
  background-color: alpha(currentColor, 0.07);
}

.gnomarchy-swatch {
  min-width: 14px;
  min-height: 14px;
}

.gnomarchy-swatch-strip {
  border-radius: 4px;
  overflow: hidden;
}
```

- [ ] **Step 3: Write the window**

Create `gui/src/window.js`:

```js
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
```

- [ ] **Step 4: Write the application entry point**

Create `gui/src/main.js`:

```js
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

application.run([system.programInvocationName, ...system.programArgs]);
```

- [ ] **Step 5: Write placeholder pages so the shell runs**

Three stubs carrying the interface the window depends on; Tasks 5–7 replace the bodies. `escape()` returns `true` when it consumed the key and `false` to let the window close.

`gui/src/pages/menu.js`:

```js
import Gtk from 'gi://Gtk?version=4.0';

export class MenuPage {
  constructor(window) {
    this._window = window;
    this.widget = new Gtk.Label({ label: 'Menu' });
  }

  focusSearch() {}

  escape() { return false; }
}
```

`gui/src/pages/keybindings.js`:

```js
import Gtk from 'gi://Gtk?version=4.0';

export class KeybindingsPage {
  constructor(window) {
    this._window = window;
    this.widget = new Gtk.Label({ label: 'Keybindings' });
  }

  focusSearch() {}

  escape() { return false; }
}
```

`gui/src/pages/manual.js`:

```js
import Gtk from 'gi://Gtk?version=4.0';

export class ManualPage {
  constructor(window) {
    this._window = window;
    this.widget = new Gtk.Label({ label: 'Manual' });
  }

  focusSearch() {}

  escape() { return false; }
}
```

- [ ] **Step 6: Run the app under WSL**

Run:

```bash
wsl -d Ubuntu -e bash -lc 'cd /mnt/c/Users/aberk/claude/Gnomarchy/.claude/worktrees/gnomarchy-gui-keyboard-c573cf && timeout 20 gjs -m gui/src/main.js --page=manual; echo "exit=$?"'
```

Expected: a window appears on the WSLg display showing the sidebar with Manual selected, and the command exits 124 (killed by `timeout`, meaning it stayed running). Any GJS traceback is a failure — read it and fix before continuing; this is the syntax check the toolchain does not otherwise have.

- [ ] **Step 7: Verify the page argument is validated**

Run:

```bash
wsl -d Ubuntu -e bash -lc 'cd /mnt/c/Users/aberk/claude/Gnomarchy/.claude/worktrees/gnomarchy-gui-keyboard-c573cf && gjs -m gui/src/main.js --page=nonsense; echo "exit=$?"'
```

Expected: prints `Unknown page: nonsense` and exits 1.

- [ ] **Step 8: Commit**

```bash
git add gui/src/main.js gui/src/window.js gui/src/lib/paths.js gui/src/pages gui/data/gnomarchy-gui.css
git commit -m "feat(gui): add the control center shell, sidebar and keyboard model"
```

---

### Task 5: Manual page

**Files:**
- Create: `gui/src/lib/manual.js`
- Modify: `gui/src/pages/manual.js` (replace the placeholder from Task 4)
- Test: `gui/tests/manual.test.js`

**Interfaces:**
- Consumes: `renderBlocks` from `lib/markdown.js` (Task 2); `GNOMARCHY_PATH`, `listDir`, `readTextFile` from `lib/paths.js` (Task 4).
- Produces:
  - `lib/manual.js` (pure except for the two path helpers): `pageTitle(fileName) -> string` — `'04-tiling.md'` → `'04  Tiling'`; `searchPages(pages, query) -> Array<{page, snippet}>` where `pages` is `Array<{file, title, text}>`.
  - `pages/manual.js`: `ManualPage` with `widget`, `focusSearch()`, `escape()`.

- [ ] **Step 1: Write the failing test**

Create `gui/tests/manual.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pageTitle, searchPages } from '../src/lib/manual.js';

test('pageTitle formats a numbered file name', () => {
  assert.equal(pageTitle('04-tiling.md'), '04  Tiling');
  assert.equal(pageTitle('16-troubleshooting.md'), '16  Troubleshooting');
  assert.equal(pageTitle('10-web-apps.md'), '10  Web apps');
});

const PAGES = [
  { file: '04-tiling.md', title: '04  Tiling', text: '# Tiling\n\nUse Super+T for the grid.\n' },
  { file: '05-themes.md', title: '05  Themes', text: '# Themes\n\nRun gnomarchy theme set.\n' },
];

test('searchPages with an empty query returns every page without a snippet', () => {
  const results = searchPages(PAGES, '');
  assert.equal(results.length, 2);
  assert.equal(results[0].snippet, '');
});

test('searchPages matches the title', () => {
  assert.deepEqual(searchPages(PAGES, 'themes').map((r) => r.page.file), ['05-themes.md']);
});

test('searchPages matches the body and returns the matching line', () => {
  const results = searchPages(PAGES, 'super+t');
  assert.equal(results.length, 1);
  assert.equal(results[0].snippet, 'Use Super+T for the grid.');
});

test('searchPages is case-insensitive and returns nothing for a miss', () => {
  assert.equal(searchPages(PAGES, 'GNOMARCHY THEME').length, 1);
  assert.equal(searchPages(PAGES, 'zzz').length, 0);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test gui/tests/manual.test.js`
Expected: FAIL — `Cannot find module '../src/lib/manual.js'`.

- [ ] **Step 3: Write the library**

Create `gui/src/lib/manual.js`:

```js
// Manual page naming and search. Pure, so it is tested under Node; the page
// module supplies the file contents.

export function pageTitle(fileName) {
  const base = fileName.replace(/\.md$/, '');
  const separator = base.indexOf('-');
  if (separator === -1) return base;
  const number = base.slice(0, separator);
  const slug = base.slice(separator + 1).replace(/-/g, ' ');
  return `${number}  ${slug.charAt(0).toUpperCase()}${slug.slice(1)}`;
}

// Full-text, the way `gnomarchy manual --grep` is, rather than title-only:
// the page you want is usually identified by a word inside it.
export function searchPages(pages, query) {
  const needle = query.trim().toLowerCase();
  if (needle === '') return pages.map((page) => ({ page, snippet: '' }));

  const results = [];
  for (const page of pages) {
    if (page.title.toLowerCase().includes(needle)) {
      results.push({ page, snippet: '' });
      continue;
    }
    const line = page.text
      .split('\n')
      .find((candidate) => candidate.toLowerCase().includes(needle));
    if (line !== undefined) results.push({ page, snippet: line.trim() });
  }
  return results;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test gui/tests/manual.test.js`
Expected: PASS, 5 tests.

- [ ] **Step 5: Write the page**

Replace `gui/src/pages/manual.js` entirely:

```js
// The manual: a searchable list of pages, and a reader.
//
// Adw.NavigationView gives the list -> page transition and the back button;
// the window's Esc rule pops it at level 3.

import GLib from 'gi://GLib';
import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';
import Pango from 'gi://Pango';

import { renderBlocks } from '../lib/markdown.js';
import { pageTitle, searchPages } from '../lib/manual.js';
import { GNOMARCHY_PATH, listDir, readTextFile } from '../lib/paths.js';

// libadwaita's own typography classes, so headings follow the system font
// scale rather than a size invented here.
const BLOCK_CSS_CLASS = {
  h1: 'title-1',
  h2: 'title-3',
  h3: 'heading',
  p: 'body',
  ul: 'body',
  ol: 'body',
  code: 'gnomarchy-code',
};

export class ManualPage {
  constructor(window) {
    this._window = window;
    this._pages = this._loadPages();

    this._search = new Gtk.SearchEntry({ placeholderText: 'Search the manual' });
    this._search.connect('search-changed', () => this._refresh());
    // Down from the entry moves into the results, so filtering and choosing
    // are one continuous keyboard motion.
    this._search.connect('activate', () => this._activateFirst());

    this._list = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.SINGLE });
    this._list.add_css_class('boxed-list');
    this._list.connect('row-activated', (_l, row) => this._open(row.gnomarchyPage));

    const listBox = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 12 });
    listBox.append(this._search);
    listBox.append(new Gtk.ScrolledWindow({ child: this._list, vexpand: true }));
    listBox.set_margin_top(12);
    listBox.set_margin_bottom(12);
    listBox.set_margin_start(12);
    listBox.set_margin_end(12);

    const listPage = new Adw.NavigationPage({ title: 'Manual', child: listBox });

    this._navigation = new Adw.NavigationView();
    this._navigation.add(listPage);

    this.widget = this._navigation;
    this._refresh();
  }

  focusSearch() {
    this._search.grab_focus();
  }

  escape() {
    // Level 3 of the window's Esc rule: leave a rendered page first.
    if (this._navigation.get_navigation_stack().get_n_items() > 1) {
      this._navigation.pop();
      return true;
    }
    // Then level 2.
    if (this._search.get_text() !== '') {
      this._search.set_text('');
      return true;
    }
    return false;
  }

  _loadPages() {
    const dir = GLib.build_filenamev([GNOMARCHY_PATH, 'manual']);
    return listDir(dir)
      .filter((name) => name.endsWith('.md'))
      .map((name) => ({
        file: name,
        title: pageTitle(name),
        text: readTextFile(GLib.build_filenamev([dir, name])) ?? '',
      }));
  }

  _refresh() {
    let row = this._list.get_first_child();
    while (row !== null) {
      const next = row.get_next_sibling();
      this._list.remove(row);
      row = next;
    }

    for (const { page, snippet } of searchPages(this._pages, this._search.get_text())) {
      const actionRow = new Adw.ActionRow({
        title: page.title,
        subtitle: snippet,
        activatable: true,
      });
      actionRow.gnomarchyPage = page;
      this._list.append(actionRow);
    }
  }

  _activateFirst() {
    const first = this._list.get_row_at_index(0);
    if (first !== null) this._open(first.gnomarchyPage);
  }

  _open(page) {
    const body = new Gtk.Box({
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 4,
    });
    body.add_css_class('gnomarchy-manual-body');

    for (const block of renderBlocks(page.text)) {
      const label = new Gtk.Label({
        label: block.markup,
        useMarkup: true,
        wrap: true,
        wrapMode: Pango.WrapMode.WORD_CHAR,
        xalign: 0,
        selectable: true,
      });
      label.add_css_class(BLOCK_CSS_CLASS[block.type]);
      body.append(label);
    }

    const scroller = new Gtk.ScrolledWindow({ child: body, vexpand: true });
    this._navigation.push(new Adw.NavigationPage({ title: page.title, child: scroller }));
  }
}
```

- [ ] **Step 6: Run the app and read a page**

Run:

```bash
wsl -d Ubuntu -e bash -lc 'cd /mnt/c/Users/aberk/claude/Gnomarchy/.claude/worktrees/gnomarchy-gui-keyboard-c573cf && timeout 30 gjs -m gui/src/main.js --page=manual; echo "exit=$?"'
```

Expected: 17 rows listed. Type `tiling` — the list narrows. Press Enter — the page renders with real headings and monospaced code blocks. Press Esc — back to the list. Press Esc again — the search clears. Press Esc again — the window closes. Exit code 0 after the final Esc.

- [ ] **Step 7: Commit**

```bash
git add gui/src/lib/manual.js gui/src/pages/manual.js gui/tests/manual.test.js
git commit -m "feat(gui): add the manual page with full-text search and a reader"
```

---

### Task 6: Menu page

**Files:**
- Create: `gui/src/lib/actions.js`, `gui/src/pages/theme-gallery.js`
- Modify: `gui/src/pages/menu.js` (replace the placeholder from Task 4)

**Interfaces:**
- Consumes: `parsePalette`, `swatchColors`, `prettyThemeName` from `lib/themes.js` (Task 3); `GNOMARCHY_PATH`, `listDir`, `readTextFile` from `lib/paths.js` (Task 4).
- Produces:
  - `lib/actions.js`: `run(argv) -> void` (fire and forget); `runForOutput(argv, onLine, onDone) -> void`; `runAndQuit(window, argv) -> void` (hides the window first).
  - `pages/theme-gallery.js`: `presentThemeGallery(window)`.
  - `pages/menu.js`: `MenuPage` with `widget`, `focusSearch()`, `escape()`.

The action set is exactly today's, regrouped — no new capabilities. Taken from `bin/gnomarchy-menu:41-137`.

- [ ] **Step 1: Write the subprocess helper**

Create `gui/src/lib/actions.js`:

```js
// Running the gnomarchy commands.
//
// Three shapes, because the actions are not alike: fire-and-forget, streams
// output into a pane, and "get the window out of the way first" (the capture
// actions, which the bash menu handled by exec'ing over its own terminal).

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

export function run(argv) {
  const process = Gio.Subprocess.new(argv, Gio.SubprocessFlags.NONE);
  // Reap it rather than leaving a zombie; failures are reported by the command
  // itself, which has a better message than anything we could invent.
  process.wait_async(null, null);
}

export function runForOutput(argv, onLine, onDone) {
  const process = Gio.Subprocess.new(
    argv,
    Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_MERGE,
  );
  const stream = new Gio.DataInputStream({ baseStream: process.get_stdout_pipe() });

  const readNext = () => {
    stream.read_line_async(GLib.PRIORITY_DEFAULT, null, (source, result) => {
      const [line] = source.read_line_finish_utf8(result);
      if (line === null) {
        process.wait_async(null, () => onDone(process.get_successful()));
        return;
      }
      onLine(line);
      readNext();
    });
  };
  readNext();
}

export function runAndQuit(window, argv) {
  window.set_visible(false);
  run(argv);
  // Give the compositor a moment to take the window down before the capture
  // tool grabs the screen, or the control center appears in the screenshot.
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 250, () => {
    window.close();
    return GLib.SOURCE_REMOVE;
  });
}
```

- [ ] **Step 2: Write the theme gallery**

Create `gui/src/pages/theme-gallery.js`:

```js
// A grid of theme cards, each showing the palette from that theme's
// alacritty.toml. Applying runs gnomarchy-theme-set, and the window's file
// monitor re-themes the app as soon as it writes the GTK CSS.

import GLib from 'gi://GLib';
import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';

import { parsePalette, swatchColors, prettyThemeName } from '../lib/themes.js';
import { GNOMARCHY_PATH, listDir, readTextFile } from '../lib/paths.js';
import { run } from '../lib/actions.js';

function themeDirectories() {
  const roots = [
    GLib.build_filenamev([GNOMARCHY_PATH, 'themes']),
    GLib.build_filenamev([GLib.get_user_config_dir(), 'gnomarchy', 'themes']),
  ];

  const found = new Map();
  for (const root of roots) {
    for (const name of listDir(root)) {
      const toml = readTextFile(GLib.build_filenamev([root, name, 'alacritty.toml']));
      if (toml === null) continue;
      const palette = parsePalette(toml);
      if (palette !== null) found.set(name, palette);
    }
  }
  return [...found.entries()].sort((a, b) => a[0].localeCompare(b[0]));
}

function swatchStrip(palette) {
  const strip = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, heightRequest: 14 });
  strip.add_css_class('gnomarchy-swatch-strip');
  for (const colour of swatchColors(palette)) {
    const cell = new Gtk.Box({ hexpand: true });
    cell.add_css_class('gnomarchy-swatch');
    const provider = new Gtk.CssProvider();
    provider.load_from_string(`box { background-color: ${colour}; }`);
    cell.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    strip.append(cell);
  }
  return strip;
}

export function presentThemeGallery(window) {
  const list = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.SINGLE });
  list.add_css_class('boxed-list');

  for (const [name, palette] of themeDirectories()) {
    const row = new Adw.ActionRow({ title: prettyThemeName(name), activatable: true });
    row.add_suffix(swatchStrip(palette));
    row.gnomarchyTheme = name;
    list.append(row);
  }

  const dialog = new Adw.Dialog({ title: 'Theme', contentWidth: 460, contentHeight: 560 });
  const view = new Adw.ToolbarView({
    content: new Gtk.ScrolledWindow({ child: list, vexpand: true, marginTop: 12,
      marginBottom: 12, marginStart: 12, marginEnd: 12 }),
  });
  view.add_top_bar(new Adw.HeaderBar());
  dialog.set_child(view);

  list.connect('row-activated', (_l, row) => {
    run(['gnomarchy-theme-set', row.gnomarchyTheme]);
    dialog.close();
  });

  dialog.present(window);
  list.grab_focus();
}
```

- [ ] **Step 3: Write the menu page**

Replace `gui/src/pages/menu.js` entirely:

```js
// The command center: every system action on one searchable surface.
//
// The bash menu nested these behind submenus (menu_webapp, menu_capture,
// menu_snapshot, menu_system, menu_power); here typing filters across all of
// them at once. The action set is exactly the same -- this is a port, not an
// expansion.

import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';

import { run, runForOutput, runAndQuit } from '../lib/actions.js';
import { presentThemeGallery } from './theme-gallery.js';

export class MenuPage {
  constructor(window) {
    this._window = window;

    this._actions = [
      { group: 'Appearance', title: 'Theme', subtitle: 'Switch the system colour theme',
        kind: 'custom', perform: () => presentThemeGallery(this._window) },

      { group: 'Web Apps', title: 'Add a web app', subtitle: 'Turn a site into an application',
        kind: 'form', fields: ['Name', 'URL'],
        perform: (values) => run(['gnomarchy-webapp', 'add', values[0], values[1]]) },
      { group: 'Web Apps', title: 'List web apps', kind: 'output',
        argv: ['gnomarchy-webapp', 'list'] },
      { group: 'Web Apps', title: 'Remove a web app', kind: 'form', fields: ['Name'],
        perform: (values) => run(['gnomarchy-webapp', 'remove', values[0]]) },

      { group: 'Capture', title: 'Annotate a region', subtitle: 'Screenshot into Satty',
        kind: 'quit', argv: ['gnomarchy-capture', 'annotate'] },
      { group: 'Capture', title: 'Region to file', kind: 'quit',
        argv: ['gnomarchy-capture', 'region'] },
      { group: 'Capture', title: 'Whole screen', kind: 'quit',
        argv: ['gnomarchy-capture', 'screen'] },

      { group: 'Snapshots', title: 'Create a snapshot', kind: 'form', fields: ['Description'],
        perform: (values) => run([
          'gnomarchy-snapshot-create', values[0] === '' ? 'Manual snapshot' : values[0],
        ]) },
      { group: 'Snapshots', title: 'List snapshots', kind: 'output',
        argv: ['gnomarchy-snapshot-list'] },

      { group: 'System', title: 'Update everything', subtitle: 'System and Gnomarchy',
        kind: 'output', argv: ['gnomarchy-update'] },
      { group: 'System', title: 'GNOME shortcuts', kind: 'output',
        argv: ['gnomarchy-gnome-hotkeys'] },
      { group: 'System', title: 'Extensions', kind: 'output',
        argv: ['gnomarchy-gnome-extensions', 'list'] },
      { group: 'System', title: 'Gaming status', kind: 'output',
        argv: ['gnomarchy-gaming', 'status'] },
      { group: 'System', title: 'Restart GNOME Shell', kind: 'quit',
        argv: ['gnomarchy-gnome-restart'] },

      { group: 'Power', title: 'Lock', kind: 'quit', argv: ['loginctl', 'lock-session'] },
      { group: 'Power', title: 'Suspend', kind: 'quit', argv: ['systemctl', 'suspend'] },
      { group: 'Power', title: 'Log out', kind: 'confirm', confirm: 'Log out now?',
        argv: ['gnome-session-quit', '--logout', '--no-prompt'] },
      { group: 'Power', title: 'Reboot', kind: 'confirm', confirm: 'Reboot now?',
        argv: ['systemctl', 'reboot'] },
      { group: 'Power', title: 'Power off', kind: 'confirm', confirm: 'Power off now?',
        argv: ['systemctl', 'poweroff'] },
    ];

    this._search = new Gtk.SearchEntry({ placeholderText: 'Search actions' });
    this._search.connect('search-changed', () => this._refresh());
    this._search.connect('activate', () => this._activateFirst());

    this._groups = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 18 });

    const column = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 12,
      marginTop: 12, marginBottom: 12, marginStart: 12, marginEnd: 12 });
    column.append(this._search);
    column.append(new Gtk.ScrolledWindow({ child: this._groups, vexpand: true }));

    this.widget = column;
    this._refresh();
  }

  focusSearch() { this._search.grab_focus(); }

  escape() {
    if (this._search.get_text() !== '') {
      this._search.set_text('');
      return true;
    }
    return false;
  }

  _matching() {
    const needle = this._search.get_text().trim().toLowerCase();
    if (needle === '') return this._actions;
    return this._actions.filter((action) =>
      `${action.group} ${action.title} ${action.subtitle ?? ''}`.toLowerCase().includes(needle));
  }

  _refresh() {
    let child = this._groups.get_first_child();
    while (child !== null) {
      const next = child.get_next_sibling();
      this._groups.remove(child);
      child = next;
    }

    this._firstAction = null;
    let currentGroup = null;
    let list = null;

    for (const action of this._matching()) {
      if (action.group !== currentGroup) {
        currentGroup = action.group;
        const group = new Adw.PreferencesGroup({ title: currentGroup });
        list = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.NONE });
        list.add_css_class('boxed-list');
        group.add(list);
        this._groups.append(group);
      }

      const row = new Adw.ActionRow({
        title: action.title,
        subtitle: action.subtitle ?? '',
        activatable: true,
      });
      row.connect('activated', () => this._perform(action));
      list.append(row);

      if (this._firstAction === null) this._firstAction = action;
    }
  }

  _activateFirst() {
    if (this._firstAction !== null) this._perform(this._firstAction);
  }

  _perform(action) {
    switch (action.kind) {
      case 'custom': action.perform(); break;
      case 'quit': runAndQuit(this._window, action.argv); break;
      case 'output': this._presentOutput(action); break;
      case 'form': this._presentForm(action); break;
      case 'confirm': this._presentConfirm(action); break;
    }
  }

  _presentConfirm(action) {
    const dialog = new Adw.AlertDialog({ heading: action.title, body: action.confirm });
    dialog.add_response('cancel', 'Cancel');
    dialog.add_response('go', action.title);
    dialog.set_response_appearance('go', Adw.ResponseAppearance.DESTRUCTIVE);
    dialog.set_default_response('go');
    dialog.set_close_response('cancel');
    dialog.connect('response', (_d, response) => {
      if (response === 'go') runAndQuit(this._window, action.argv);
    });
    dialog.present(this._window);
  }

  _presentForm(action) {
    const entries = action.fields.map((field) => new Adw.EntryRow({ title: field }));
    const list = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.NONE });
    list.add_css_class('boxed-list');
    for (const entry of entries) list.append(entry);

    const dialog = new Adw.AlertDialog({ heading: action.title, extraChild: list });
    dialog.add_response('cancel', 'Cancel');
    dialog.add_response('go', 'Apply');
    dialog.set_response_appearance('go', Adw.ResponseAppearance.SUGGESTED);
    dialog.set_default_response('go');
    dialog.set_close_response('cancel');
    dialog.connect('response', (_d, response) => {
      if (response === 'go') action.perform(entries.map((entry) => entry.get_text()));
    });
    dialog.present(this._window);
    entries[0].grab_focus();
  }

  _presentOutput(action) {
    const buffer = new Gtk.TextBuffer();
    const view = new Gtk.TextView({ buffer, editable: false, monospace: true });
    const scroller = new Gtk.ScrolledWindow({ child: view, vexpand: true, widthRequest: 620,
      heightRequest: 420 });

    const dialog = new Adw.Dialog({ title: action.title, contentWidth: 660, contentHeight: 480 });
    const toolbar = new Adw.ToolbarView({ content: scroller });
    toolbar.add_top_bar(new Adw.HeaderBar());
    dialog.set_child(toolbar);
    dialog.present(this._window);

    runForOutput(
      action.argv,
      (line) => buffer.insert(buffer.get_end_iter(), `${line}\n`, -1),
      (successful) => {
        if (!successful) {
          buffer.insert(buffer.get_end_iter(), '\n[command exited with an error]\n', -1);
        }
      },
    );
  }
}
```

- [ ] **Step 4: Run the app and exercise the page**

Run:

```bash
wsl -d Ubuntu -e bash -lc 'cd /mnt/c/Users/aberk/claude/Gnomarchy/.claude/worktrees/gnomarchy-gui-keyboard-c573cf && timeout 40 gjs -m gui/src/main.js --page=menu; echo "exit=$?"'
```

Expected: six groups render. Typing `power` narrows to the Power group. Opening **Theme** shows a scrollable list of theme names each with an eight-colour strip. Note that the `gnomarchy-*` commands do not exist inside WSL, so an `output` action will show the command's own "not found" error in the pane — that is the correct behaviour being observed, not a defect; what is being verified here is that the pane opens, streams and reports failure rather than hanging.

- [ ] **Step 5: Commit**

```bash
git add gui/src/lib/actions.js gui/src/pages/theme-gallery.js gui/src/pages/menu.js
git commit -m "feat(gui): add the menu page with a flat searchable action list and theme gallery"
```

---

### Task 7: Keybindings page, read-only

**Files:**
- Create: `gui/src/lib/keysources.js`
- Modify: `gui/src/pages/keybindings.js` (replace the placeholder from Task 4)

**Interfaces:**
- Consumes: `formatAccel`, `normalizeAccel` from `lib/accel.js` (Task 1).
- Produces, from `lib/keysources.js`:
  - `readBindings() -> Array<Binding>` where `Binding` is `{id, section, accel, description, kind, schemaId, key, path}`. `kind` is `'strv'` (a `Gio.Settings` key of type `as`) or `'custom'` (a relocatable custom-keybinding slot). `id` is unique and stable within a run.
  - `writeBinding(binding, accel) -> void` — `accel` of `''` unbinds.
  - `onBindingsChanged(callback) -> void` — fires when any watched schema changes.

The six sources and their ordering are taken from `bin/gnomarchy-keybindings:106-160`.

- [ ] **Step 1: Write the dconf reader**

Create `gui/src/lib/keysources.js`:

```js
// Every keybinding actually in effect, read through Gio.Settings.
//
// The bash original parsed the output of `gsettings` and had to special-case
// "@as []" by hand (bin/gnomarchy-keybindings:36). Typed access removes that,
// and -- unlike string parsing -- it can also write, which the editor needs.

import Gio from 'gi://Gio';

import { normalizeAccel } from './accel.js';

const MEDIA_KEYS = 'org.gnome.settings-daemon.plugins.media-keys';
const CUSTOM_SCHEMA = `${MEDIA_KEYS}.custom-keybinding`;
const TILING_SHELL = 'org.gnome.shell.extensions.tilingshell';
const TACTILE = 'org.gnome.shell.extensions.tactile';

const SCHEMA_SECTIONS = [
  ['org.gnome.desktop.wm.keybindings', 'Windows & Workspaces'],
  ['org.gnome.shell.keybindings', 'Shell'],
  ['org.gnome.mutter.keybindings', 'Mutter'],
];

const TILING_LABELS = {
  'focus-window-left': 'Focus window left',
  'focus-window-down': 'Focus window down',
  'focus-window-up': 'Focus window up',
  'focus-window-right': 'Focus window right',
  'move-window-left': 'Move window left',
  'move-window-down': 'Move window down',
  'move-window-up': 'Move window up',
  'move-window-right': 'Move window right',
  'move-window-center': 'Centre window',
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

function readStrvSchema(schemaId, section, keyFilter, labelFor) {
  if (!schemaExists(schemaId)) return [];
  const schema = source.lookup(schemaId, true);
  const settings = new Gio.Settings({ schemaId });
  const bindings = [];

  for (const key of schema.list_keys().sort()) {
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

function tilingShellEnabled() {
  if (!schemaExists('org.gnome.shell') || !schemaExists(TILING_SHELL)) return false;
  const shell = new Gio.Settings({ schemaId: 'org.gnome.shell' });
  return shell.get_strv('enabled-extensions').some((name) => name.includes('tilingshell'));
}

export function readBindings() {
  const bindings = [...readCustomSlots()];

  // Tiling Shell's directional bindings only apply in dynamic tiling mode, so
  // listing them when the extension is off would be a lie.
  if (tilingShellEnabled()) {
    bindings.push(...readStrvSchema(
      TILING_SHELL, 'Dynamic Tiling',
      (key) => Object.hasOwn(TILING_LABELS, key),
      (key) => TILING_LABELS[key],
    ));
  }

  for (const [schemaId, section] of SCHEMA_SECTIONS) {
    bindings.push(...readStrvSchema(schemaId, section, null, null));
  }

  bindings.push(...readStrvSchema(
    TACTILE, 'Manual Tiling (Tactile)',
    (key) => key === 'show-tiles',
    () => 'Open the tiling grid overlay',
  ));

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
  const watched = [MEDIA_KEYS, TILING_SHELL, TACTILE, ...SCHEMA_SECTIONS.map(([id]) => id)];
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
```

- [ ] **Step 2: Write the page, read-only for now**

Replace `gui/src/pages/keybindings.js` entirely:

```js
// Every keybinding in effect, searchable. Task 8 makes the rows editable.

import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';

import { formatAccel } from '../lib/accel.js';
import { readBindings, onBindingsChanged } from '../lib/keysources.js';

export class KeybindingsPage {
  constructor(window) {
    this._window = window;

    this._search = new Gtk.SearchEntry({ placeholderText: 'Search keybindings' });
    this._search.connect('search-changed', () => this._refresh());

    this._groups = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 18 });

    const column = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 12,
      marginTop: 12, marginBottom: 12, marginStart: 12, marginEnd: 12 });
    column.append(this._search);
    column.append(new Gtk.ScrolledWindow({ child: this._groups, vexpand: true }));

    this.widget = column;
    this._reload();

    // The list must never be stale if something changes dconf underneath it.
    onBindingsChanged(() => this._reload());
  }

  focusSearch() { this._search.grab_focus(); }

  escape() {
    if (this._search.get_text() !== '') {
      this._search.set_text('');
      return true;
    }
    return false;
  }

  _reload() {
    this._bindings = readBindings();
    this._refresh();
  }

  _matching() {
    const needle = this._search.get_text().trim().toLowerCase();
    if (needle === '') return this._bindings;
    return this._bindings.filter((binding) =>
      `${binding.description} ${formatAccel(binding.accel)} ${binding.section}`
        .toLowerCase().includes(needle));
  }

  _refresh() {
    let child = this._groups.get_first_child();
    while (child !== null) {
      const next = child.get_next_sibling();
      this._groups.remove(child);
      child = next;
    }

    let currentSection = null;
    let list = null;

    for (const binding of this._matching()) {
      if (binding.section !== currentSection) {
        currentSection = binding.section;
        const group = new Adw.PreferencesGroup({ title: currentSection });
        list = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.NONE });
        list.add_css_class('boxed-list');
        group.add(list);
        this._groups.append(group);
      }

      const row = new Adw.ActionRow({
        title: binding.description,
        subtitle: formatAccel(binding.accel),
        activatable: true,
      });
      row.gnomarchyBinding = binding;
      list.append(row);
    }
  }
}
```

- [ ] **Step 3: Run the app**

Run:

```bash
wsl -d Ubuntu -e bash -lc 'cd /mnt/c/Users/aberk/claude/Gnomarchy/.claude/worktrees/gnomarchy-gui-keyboard-c573cf && timeout 30 gjs -m gui/src/main.js --page=keybindings; echo "exit=$?"'
```

Expected: the page loads without a traceback. WSL has few of these schemas installed, so the list may be short or empty — what is being verified is that missing schemas are skipped rather than throwing. If a `Gio.Settings` schema-not-found abort appears, `schemaExists` is being bypassed somewhere; fix that before continuing.

- [ ] **Step 4: Commit**

```bash
git add gui/src/lib/keysources.js gui/src/pages/keybindings.js
git commit -m "feat(gui): read every active keybinding through typed Gio.Settings"
```

---

### Task 8: Keybindings editing

**Files:**
- Create: `gui/src/pages/accel-dialog.js`
- Modify: `gui/src/pages/keybindings.js`, `gui/src/lib/keysources.js`
- Test: `gui/tests/conflicts.test.js`

**Interfaces:**
- Consumes: `isValidAccel`, `normalizeAccel`, `formatAccel` from `lib/accel.js`; `readBindings`, `writeBinding` from `lib/keysources.js`.
- Produces:
  - `lib/keysources.js` gains `findConflict(bindings, accel, excludeId) -> Binding | null` (pure over its arguments, so it is unit-tested).
  - `pages/accel-dialog.js`: `presentAccelDialog(window, binding, {onAccel})`.

**Deviation from the spec, stated deliberately.** The spec makes a `Gdk.Toplevel.inhibit_system_shortcuts()` spike the gate for this task. WSLg runs Weston, not mutter, so it *cannot* answer that question — only real GNOME can, which would stall this task behind a full CI run. Instead the dialog offers **both** input paths in one view: press the combination, or type it into an entry. Inhibiting is still requested, so press-to-capture works wherever the compositor allows it; if GNOME grabs the key, the typed entry is already there rather than needing a follow-up change. The cost is roughly fifteen lines, which is less than the cost of blocking.

- [ ] **Step 1: Write the failing conflict test**

Create `gui/tests/conflicts.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { findConflict } from '../src/lib/conflicts.js';

const BINDINGS = [
  { id: 'a', accel: '<Super>k', description: 'Keybindings' },
  { id: 'b', accel: '<Super><Shift>k', description: 'Manual' },
  { id: 'c', accel: '<Control><Alt>t', description: 'Terminal' },
];

test('findConflict returns the binding already holding the accelerator', () => {
  assert.equal(findConflict(BINDINGS, '<Super>k', 'zzz').description, 'Keybindings');
});

test('findConflict compares normalised forms', () => {
  assert.equal(findConflict(BINDINGS, '<Shift><Super>K', 'zzz').description, 'Manual');
  assert.equal(findConflict(BINDINGS, '<Primary><Alt>t', 'zzz').description, 'Terminal');
});

test('findConflict ignores the row being edited', () => {
  assert.equal(findConflict(BINDINGS, '<Super>k', 'a'), null);
});

test('findConflict returns null for a free accelerator and for junk', () => {
  assert.equal(findConflict(BINDINGS, '<Super>z', 'zzz'), null);
  assert.equal(findConflict(BINDINGS, '@as []', 'zzz'), null);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test gui/tests/conflicts.test.js`
Expected: FAIL — `Cannot find module '../src/lib/conflicts.js'`.

- [ ] **Step 3: Write the conflict finder as its own pure module**

`findConflict` must be testable under Node, so it cannot live in `keysources.js` (which imports `gi://`). Create `gui/src/lib/conflicts.js`:

```js
// Which binding, if any, already owns an accelerator.
//
// Kept out of keysources.js so that it stays free of gi:// imports and can be
// unit-tested under Node. keysources.js re-exports it for convenience.

import { normalizeAccel } from './accel.js';

export function findConflict(bindings, accel, excludeId) {
  const wanted = normalizeAccel(accel);
  if (wanted === null) return null;
  return bindings.find((binding) =>
    binding.id !== excludeId && normalizeAccel(binding.accel) === wanted) ?? null;
}
```

Add to the end of `gui/src/lib/keysources.js`:

```js
export { findConflict } from './conflicts.js';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test gui/tests/conflicts.test.js`
Expected: PASS, 4 tests.

- [ ] **Step 5: Write the capture dialog**

Create `gui/src/pages/accel-dialog.js`:

```js
// Capture a new accelerator for one binding.
//
// Two ways in, on purpose. Under Wayland the compositor may grab a
// combination (Super+Q, say) before this window ever sees it;
// inhibit_system_shortcuts asks it not to, and GNOME Settings relies on the
// same call. Where that is refused the typed entry is already present, so the
// dialog degrades instead of breaking.

import Gdk from 'gi://Gdk?version=4.0';
import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw?version=1';

import { formatAccel, isValidAccel, normalizeAccel } from '../lib/accel.js';

const MODIFIER_KEYVALS = new Set([
  Gdk.KEY_Shift_L, Gdk.KEY_Shift_R, Gdk.KEY_Control_L, Gdk.KEY_Control_R,
  Gdk.KEY_Alt_L, Gdk.KEY_Alt_R, Gdk.KEY_Super_L, Gdk.KEY_Super_R,
  Gdk.KEY_Meta_L, Gdk.KEY_Meta_R, Gdk.KEY_ISO_Level3_Shift,
]);

function accelFromEvent(keyval, state) {
  const parts = [];
  if ((state & Gdk.ModifierType.CONTROL_MASK) !== 0) parts.push('<Control>');
  if ((state & Gdk.ModifierType.ALT_MASK) !== 0) parts.push('<Alt>');
  if ((state & Gdk.ModifierType.SHIFT_MASK) !== 0) parts.push('<Shift>');
  if ((state & Gdk.ModifierType.SUPER_MASK) !== 0) parts.push('<Super>');
  const name = Gdk.keyval_name(Gdk.keyval_to_lower(keyval));
  if (name === null) return null;
  return normalizeAccel(parts.join('') + name);
}

export function presentAccelDialog(window, binding, { onAccel }) {
  const status = new Gtk.Label({
    label: `Press the new shortcut for “${binding.description}”`,
    wrap: true,
  });
  status.add_css_class('title-4');

  const current = new Gtk.Label({ label: formatAccel(binding.accel) });
  current.add_css_class('dim-label');

  const typed = new Adw.EntryRow({ title: 'Or type it, e.g. <Super>q' });
  const typedList = new Gtk.ListBox({ selectionMode: Gtk.SelectionMode.NONE });
  typedList.add_css_class('boxed-list');
  typedList.append(typed);

  const box = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 12 });
  box.append(status);
  box.append(current);
  box.append(typedList);

  const dialog = new Adw.AlertDialog({ heading: 'Set shortcut', extraChild: box });
  dialog.add_response('cancel', 'Cancel');
  dialog.add_response('unbind', 'Unbind');
  dialog.add_response('apply', 'Apply');
  dialog.set_response_appearance('apply', Adw.ResponseAppearance.SUGGESTED);
  dialog.set_close_response('cancel');

  const controller = new Gtk.EventControllerKey();
  controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);
  controller.connect('key-pressed', (_c, keyval, _code, state) => {
    // Let the user reach the entry and the buttons.
    if (keyval === Gdk.KEY_Escape || keyval === Gdk.KEY_Tab) return Gdk.EVENT_PROPAGATE;
    if (window.get_focus() instanceof Gtk.Editable) return Gdk.EVENT_PROPAGATE;
    // A modifier on its own is not an accelerator; wait for the real key.
    if (MODIFIER_KEYVALS.has(keyval)) return Gdk.EVENT_PROPAGATE;
    // Call the handler directly rather than synthesising a response: emitting
    // one on an AdwAlertDialog from outside is not part of its API.
    if (keyval === Gdk.KEY_BackSpace) {
      onAccel('');
      dialog.close();
      return Gdk.EVENT_STOP;
    }

    const accel = accelFromEvent(keyval, state);
    if (accel === null || !isValidAccel(accel)) {
      status.set_label('That cannot be a shortcut on its own. Add Ctrl, Alt or Super.');
      return Gdk.EVENT_STOP;
    }
    onAccel(accel);
    dialog.close();
    return Gdk.EVENT_STOP;
  });
  dialog.add_controller(controller);

  dialog.connect('response', (_d, response) => {
    if (response === 'unbind') { onAccel(''); return; }
    if (response !== 'apply') return;
    const text = typed.get_text().trim();
    const accel = normalizeAccel(text);
    if (accel !== null && isValidAccel(accel)) onAccel(accel);
  });

  dialog.present(window);

  // Ask the compositor to stop eating Super/Alt combinations while this is up.
  // GNOME Settings makes the same request; a compositor is free to refuse,
  // which is why the typed entry exists.
  const surface = window.get_surface();
  if (surface !== null && typeof surface.inhibit_system_shortcuts === 'function') {
    surface.inhibit_system_shortcuts(null);
    dialog.connect('closed', () => surface.restore_system_shortcuts());
  }
}
```

- [ ] **Step 6: Wire editing into the page**

In `gui/src/pages/keybindings.js`, extend the imports:

```js
import { formatAccel } from '../lib/accel.js';
import { readBindings, writeBinding, findConflict, onBindingsChanged } from '../lib/keysources.js';
import { presentAccelDialog } from './accel-dialog.js';
```

In `_refresh()`, make each row open the dialog — replace the `row.gnomarchyBinding = binding;` line with:

```js
      row.gnomarchyBinding = binding;
      row.connect('activated', () => this._edit(binding));
```

Add these two methods to the class:

```js
  _edit(binding) {
    presentAccelDialog(this._window, binding, {
      onAccel: (accel) => {
        if (accel === '') { writeBinding(binding, ''); this._reload(); return; }

        const clash = findConflict(this._bindings, accel, binding.id);
        if (clash === null) { writeBinding(binding, accel); this._reload(); return; }

        this._confirmReplace(binding, accel, clash);
      },
    });
  }

  _confirmReplace(binding, accel, clash) {
    const dialog = new Adw.AlertDialog({
      heading: 'Already in use',
      body: `${formatAccel(accel)} is bound to “${clash.description}”.\n`
        + 'Replacing it will leave that action with no shortcut.',
    });
    dialog.add_response('cancel', 'Cancel');
    dialog.add_response('replace', 'Replace');
    dialog.set_response_appearance('replace', Adw.ResponseAppearance.DESTRUCTIVE);
    dialog.set_close_response('cancel');
    dialog.connect('response', (_d, response) => {
      if (response !== 'replace') return;
      writeBinding(clash, '');
      writeBinding(binding, accel);
      this._reload();
    });
    dialog.present(this._window);
  }
```

- [ ] **Step 7: Add the reset action to the page header**

Reset must not own a second copy of the defaults — it delegates to the layout the machine already records. Add to the imports in `gui/src/pages/keybindings.js`:

```js
import { run } from '../lib/actions.js';
```

and append this button to the column, immediately after `column.append(this._search);`:

```js
    // Delegates to gnomarchy-keymap via the existing reset path, so
    // bin/gnomarchy-keymap stays the only definition of what the defaults are.
    const reset = new Gtk.Button({ label: 'Reset to layout defaults', halign: Gtk.Align.END });
    reset.connect('clicked', () => {
      const dialog = new Adw.AlertDialog({
        heading: 'Reset shortcuts',
        body: 'Re-apply the keyboard layout this machine is set to. Your changes to shortcuts will be lost.',
      });
      dialog.add_response('cancel', 'Cancel');
      dialog.add_response('reset', 'Reset');
      dialog.set_response_appearance('reset', Adw.ResponseAppearance.DESTRUCTIVE);
      dialog.set_close_response('cancel');
      dialog.connect('response', (_d, response) => {
        if (response === 'reset') run(['gnomarchy-keybindings', 'reset']);
      });
      dialog.present(this._window);
    });
    column.append(reset);
```

- [ ] **Step 8: Run the app and edit a binding**

Run:

```bash
wsl -d Ubuntu -e bash -lc 'cd /mnt/c/Users/aberk/claude/Gnomarchy/.claude/worktrees/gnomarchy-gui-keyboard-c573cf && timeout 60 gjs -m gui/src/main.js --page=keybindings; echo "exit=$?"'
```

Expected: activating a row opens the dialog; pressing `Ctrl+Alt+Y` closes it and the row's subtitle becomes `Ctrl + Alt + Y`; re-opening and pressing a combination already listed raises the "Already in use" dialog naming the other action; pressing `Backspace` clears the binding. If WSL exposes no editable schema, install one to test against with `gsettings` or verify this step on the real machine and say so in the commit message rather than marking it passed.

- [ ] **Step 9: Commit**

```bash
git add gui/src/lib/conflicts.js gui/src/lib/keysources.js gui/src/pages/accel-dialog.js gui/src/pages/keybindings.js gui/tests/conflicts.test.js
git commit -m "feat(gui): make keybindings editable with conflict detection"
```

---

### Task 9: Entry points

The three commands become GUI launchers with the existing TUI as fallback.

**Files:**
- Modify: `bin/gnomarchy-menu`, `bin/gnomarchy-keybindings`, `bin/gnomarchy-manual`
- Create: `install/helpers/gui.sh`

**Interfaces:**
- Consumes: `gui/src/main.js` (Task 4).
- Produces: `gnomarchy_launch_gui <page>` — execs the GUI and does not return; returns non-zero without running anything when the GUI is unavailable, so the caller falls through to its text path.

- [ ] **Step 1: Write the launcher helper**

Create `install/helpers/gui.sh`:

```bash
#!/bin/bash

# Launching the control center, with an honest fallback.
#
# The GUI is the face of these three commands, but it must never be the only
# way in: over SSH, in a TTY, and on the half-installed system where the
# troubleshooting page matters most, there is no display and possibly no gjs.
# In those cases this returns non-zero and the caller uses its text path.

gnomarchy_launch_gui() {
  local page="$1"
  local root="${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}"
  local entry="$root/gui/src/main.js"

  [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]] || return 1
  command -v gjs >/dev/null || return 1
  [[ -f "$entry" ]] || return 1

  exec gjs -m "$entry" "--page=$page"
}
```

- [ ] **Step 2: Convert `bin/gnomarchy-menu`**

Delete the terminal re-exec block at `bin/gnomarchy-menu:13-29` and insert, immediately after the `export PATH=` line:

```bash
# The GUI is the face of this command; the gum menu below is the fallback for
# a TTY or a machine without gjs.
source "$GNOMARCHY_PATH/install/helpers/gui.sh"
gnomarchy_launch_gui menu || true
```

`|| true` is correct here and is the exception the convention allows: a non-zero return is the documented "no GUI available, use the text path" signal, not a failure. Leave a comment saying so.

- [ ] **Step 3: Convert `bin/gnomarchy-manual`**

Delete the terminal re-exec block at `bin/gnomarchy-manual:19-27`. In the `case` statement, change the `browse | "")` branch to try the GUI first:

```bash
  browse | "")
    source "$GNOMARCHY_PATH/install/helpers/gui.sh"
    # Non-zero means no display or no gjs; fall through to the text browser.
    gnomarchy_launch_gui manual || true
    browse
    ;;
```

`--list`, `--grep` and the page-by-name branches are unchanged: they are pure text and must stay that way for piping and for SSH.

- [ ] **Step 4: Convert `bin/gnomarchy-keybindings`**

Delete the terminal re-exec block at `bin/gnomarchy-keybindings:18-26`. Change the `search | "")` branch to:

```bash
  search | "")
    source "${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}/install/helpers/gui.sh"
    # Non-zero means no display or no gjs; fall through to the text list.
    gnomarchy_launch_gui keybindings || true
    output="$(collect)"
    echo "$output"
    ;;
```

The `gum filter` block is removed with it: the GUI is the interactive surface now, and a second interactive UI would drift. `--list` and `reset` are unchanged.

- [ ] **Step 5: Verify the fallback path with no display**

Run:

```bash
wsl -d Ubuntu -e bash -lc 'cd /mnt/c/Users/aberk/claude/Gnomarchy/.claude/worktrees/gnomarchy-gui-keyboard-c573cf && env -u WAYLAND_DISPLAY -u DISPLAY GNOMARCHY_PATH=$PWD bash bin/gnomarchy-manual --list | head -3'
```

Expected: the three first manual page titles, printed as text — proving the fallback works when there is no display.

- [ ] **Step 6: Verify the GUI path**

Run:

```bash
wsl -d Ubuntu -e bash -lc 'cd /mnt/c/Users/aberk/claude/Gnomarchy/.claude/worktrees/gnomarchy-gui-keyboard-c573cf && GNOMARCHY_PATH=$PWD timeout 15 bash bin/gnomarchy-manual; echo "exit=$?"'
```

Expected: the control center window opens on the Manual page; exit code 124 from `timeout`.

- [ ] **Step 7: Mark the helper executable in git and commit**

```bash
git update-index --add --chmod=+x install/helpers/gui.sh
git add install/helpers/gui.sh bin/gnomarchy-menu bin/gnomarchy-manual bin/gnomarchy-keybindings
git commit -m "feat(gui): make the three commands open the control center, with a text fallback"
```

---

### Task 10: Packaging, install stage and migration

**Files:**
- Modify: `install/gnomarchy-base.packages`, `install/config/all.sh`
- Create: `install/config/control-center.sh`, `default/applications/org.gnomarchy.ControlCenter.desktop`, `migrations/2026-09-12-1200-control-center-gui.sh`

**Interfaces:**
- Consumes: `gui/src/main.js` (Task 4).
- Produces: the `.desktop` file at `~/.local/share/applications/org.gnomarchy.ControlCenter.desktop` on installed machines.

- [ ] **Step 1: Verify the package names against the real database**

Run:

```bash
for p in gjs gtk4 libadwaita; do echo -n "$p: "; curl -sSL "https://archlinux.org/packages/search/json/?name=$p" | grep -o '"repo": *"[a-z]*"' | head -1; echo; done
```

Expected: each prints `"repo": "extra"`. A name that returns nothing must not be added — `pacman -S` is all-or-nothing and one unknown name aborts the installer.

- [ ] **Step 2: Add the packages**

In `install/gnomarchy-base.packages`, add next to the other GNOME entries:

```
gjs
gtk4
libadwaita
```

`gnome-shell` already pulls all three transitively; listing them makes the control center's dependency a stated fact rather than a lucky inheritance.

- [ ] **Step 3: Write the desktop entry**

Create `default/applications/org.gnomarchy.ControlCenter.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Gnomarchy
Comment=Themes, shortcuts, capture, snapshots and the manual
Exec=gnomarchy-menu
Icon=preferences-desktop
Terminal=false
Categories=GNOME;GTK;Settings;
Keywords=gnomarchy;theme;keybindings;manual;snapshot;
StartupWMClass=org.gnomarchy.ControlCenter
```

- [ ] **Step 4: Write the install stage**

Create `install/config/control-center.sh`, following the shape of `install/config/hooks.sh`:

```bash
#!/bin/bash

gnomarchy_header "Installing the Gnomarchy Control Center"

# Nothing is built: the app is GJS source that arrives with the repository and
# updates with `git pull`, like everything else here. All this stage does is
# publish the desktop entry so the app is reachable from the Overview as well
# as from Super+Alt+Space.
#
# No dconf is written, so this works inside arch-chroot: the three commands
# that launch it are already bound by install/desktop/set-gnome-hotkeys.sh.
APPLICATIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP_SOURCE="$GNOMARCHY_PATH/default/applications/org.gnomarchy.ControlCenter.desktop"

if [[ ! -f "$DESKTOP_SOURCE" ]]; then
  gnomarchy_warn "No desktop entry at $DESKTOP_SOURCE; skipping."
  return 0 2>/dev/null || exit 0
fi

mkdir -p "$APPLICATIONS_DIR"
cp -f "$DESKTOP_SOURCE" "$APPLICATIONS_DIR/"

gnomarchy_step "Control center published to $APPLICATIONS_DIR"
```

- [ ] **Step 5: Source the stage**

In `install/config/all.sh`, add after the `hooks.sh` line:

```bash
source "$GNOMARCHY_INSTALL/config/control-center.sh"
```

- [ ] **Step 6: Write the migration**

Create `migrations/2026-09-12-1200-control-center-gui.sh`:

```bash
#!/bin/bash

# The menu, the keybindings browser and the manual are now one GTK
# application. Adding gjs/gtk4/libadwaita to gnomarchy-base.packages reaches
# new installs only, so an existing machine needs them installed here.
#
# Keybindings are deliberately untouched: the three commands that open the GUI
# keep the names they always had, so whatever they were bound to still works.
#
# Idempotent: --needed installs nothing that is already present, and cp -f
# rewrites a file that may already be identical. Needs no session bus, unlike
# most migrations here.
set -eEo pipefail

GNOMARCHY_PATH="${GNOMARCHY_PATH:-$HOME/.local/share/gnomarchy}"

echo "Installing the control center's runtime..."
sudo pacman -S --needed --noconfirm gjs gtk4 libadwaita

DESKTOP_SOURCE="$GNOMARCHY_PATH/default/applications/org.gnomarchy.ControlCenter.desktop"
APPLICATIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

if [[ -f "$DESKTOP_SOURCE" ]]; then
  mkdir -p "$APPLICATIONS_DIR"
  cp -f "$DESKTOP_SOURCE" "$APPLICATIONS_DIR/"
  echo "  Published the control center desktop entry."
else
  echo "  No desktop entry found at $DESKTOP_SOURCE; run 'gnomarchy update' first." >&2
fi

echo "The control center is installed. Super+Alt+Space, Super+K and Super+Shift+K now open it."
```

- [ ] **Step 7: Check the scripts parse**

Run:

```bash
bash -n install/config/control-center.sh && bash -n migrations/2026-09-12-1200-control-center-gui.sh && bash -n install/helpers/gui.sh && echo "all parse"
```

Expected: `all parse`.

- [ ] **Step 8: Mark executable in git and commit**

```bash
git update-index --add --chmod=+x install/config/control-center.sh migrations/2026-09-12-1200-control-center-gui.sh
git add install/gnomarchy-base.packages install/config/all.sh install/config/control-center.sh default/applications migrations/2026-09-12-1200-control-center-gui.sh
git commit -m "feat(install): install the control center and migrate existing machines"
```

---

### Task 11: CI verification

Every check here corresponds to a way this change can break.

**Files:**
- Modify: `iso/tests/verify-install.sh`, `iso/tests/verify-session.sh`, `iso/tests/capture-screenshots.sh`
- Create: `iso/tests/verify-manual-subset.js`

**Interfaces:**
- Consumes: `unsupported` from `lib/markdown.js` (Task 2); the `ok`/`no` harnesses already defined in both verify scripts.

- [ ] **Step 1: Add the offline checks**

Append to `iso/tests/verify-install.sh`, before its final summary:

```bash
# --- The control center ----------------------------------------------------
for pkg in gjs gtk4 libadwaita; do
  if [[ -d "$ROOT/var/lib/pacman/local" ]] &&
    compgen -G "$ROOT/var/lib/pacman/local/$pkg-[0-9]*" >/dev/null; then
    ok "$pkg is installed"
  else
    no "$pkg is not installed" "the control center cannot start without it"
  fi
done

GUI_ENTRY="$HOME_DIR/.local/share/gnomarchy/gui/src/main.js"
if [[ -f "$GUI_ENTRY" ]]; then
  ok "control center source is present"
else
  no "no control center at $GUI_ENTRY"
fi

DESKTOP_ENTRY="$HOME_DIR/.local/share/applications/org.gnomarchy.ControlCenter.desktop"
if [[ -f "$DESKTOP_ENTRY" ]]; then
  ok "control center desktop entry is published"
else
  no "no desktop entry at $DESKTOP_ENTRY" "install/config/control-center.sh did not run"
fi

# A half-applied port -- GUI files present but the commands still spawning a
# terminal -- would otherwise pass every check above.
terminal_relics=0
for cmd in gnomarchy-menu gnomarchy-manual gnomarchy-keybindings; do
  script="$HOME_DIR/.local/share/gnomarchy/bin/$cmd"
  [[ -f "$script" ]] || continue
  if grep -q 'exec gnome-terminal\|exec alacritty' "$script"; then
    terminal_relics=$((terminal_relics + 1))
    no "$cmd still re-execs into a terminal"
  fi
done
(( terminal_relics == 0 )) && ok "the three commands no longer spawn a terminal"
```

- [ ] **Step 2: Write the manual subset checker**

Create `iso/tests/verify-manual-subset.js`:

```js
// Fails when a manual page uses Markdown the control center cannot render.
//
// The renderer supports headings, paragraphs, bold, italic, inline code,
// fenced code and lists -- the subset the pages actually use. Without this
// check, adding a table to a page would silently render as "| a | b |".
//
// Usage: node iso/tests/verify-manual-subset.js [manual-dir]

import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import { unsupported } from '../../gui/src/lib/markdown.js';

const directory = process.argv[2] ?? 'manual';
let failures = 0;

for (const name of readdirSync(directory).sort()) {
  if (!name.endsWith('.md')) continue;
  for (const { line, kind } of unsupported(readFileSync(join(directory, name), 'utf8'))) {
    console.error(`FAIL  ${name}:${line}  unsupported ${kind}`);
    failures += 1;
  }
}

if (failures === 0) console.log('PASS  every manual page is within the renderable subset');
process.exit(failures === 0 ? 0 : 1);
```

- [ ] **Step 3: Run the subset checker**

Run: `node iso/tests/verify-manual-subset.js manual`
Expected: `PASS  every manual page is within the renderable subset`, exit 0.

- [ ] **Step 4: Add the session check**

Append to `iso/tests/verify-session.sh`, before its summary:

```bash
# --- The control center ----------------------------------------------------
# GJS has no compile step, so a syntax error or a bad import is invisible until
# something runs the app. An application that owns its D-Bus name has parsed
# every module and built its window, which makes this the compiler this stack
# does not otherwise have.
trace "launching the control center"
setsid gnomarchy-menu >/var/tmp/gnomarchy-gui.log 2>&1 &
gui_pid=$!

owned=0
for _ in $(seq 1 20); do
  if busctl --user list --no-legend --no-pager | grep -q org.gnomarchy.ControlCenter; then
    owned=1
    break
  fi
  sleep 1
done

if (( owned )); then
  ok "control center owns org.gnomarchy.ControlCenter"
else
  no "control center never appeared on the session bus" "$(tail -n 5 /var/tmp/gnomarchy-gui.log)"
fi

kill "$gui_pid" 2>/dev/null || true  # already gone if it crashed; not a failure
```

- [ ] **Step 5: Add the screenshot stages**

In `iso/tests/capture-screenshots.sh`, replace the existing `stage 03-command-center` line with a sequence that shows all three pages. `launch` and `stage` are the script's own helpers (`capture-screenshots.sh:98-112`):

```bash
launch gnomarchy-menu
stage 03-control-center-menu

launch gnomarchy-keybindings
stage 04-control-center-keybindings

launch gnomarchy-manual
stage 05-control-center-manual
```

Renumber the stages that follow so the sequence stays ordered.

- [ ] **Step 6: Check the scripts parse**

Run: `bash -n iso/tests/verify-install.sh && bash -n iso/tests/verify-session.sh && bash -n iso/tests/capture-screenshots.sh && echo "all parse"`
Expected: `all parse`.

- [ ] **Step 7: Commit**

```bash
git update-index --add --chmod=+x iso/tests/verify-manual-subset.js
git add iso/tests/
git commit -m "test(ci): verify the control center installs, starts and renders"
```

---

### Task 12: Documentation

`CLAUDE.md`: documentation is a claim about the code.

**Files:**
- Modify: `README.md`, `AGENTS.md`, `manual/07-the-menu.md`, `manual/03-keybindings.md`, `CLAUDE.md`

- [ ] **Step 1: Fix the README's command-center and manual claims**

In `README.md`:
- Line 25 describes the command center as "a single searchable menu" — change it to say it is a GTK application with three pages, opened by Super+Alt+Space, Super+K and Super+Shift+K.
- Lines 197–208 describe `gnomarchy manual` as a terminal browser. Rewrite: the GUI is the default; `--list`, `--grep` and `<page>` remain text for piping and for SSH; and the TTY fallback is still there, which is the paragraph's actual point.
- **Line 203 says "Sixteen pages" and there are seventeen.** Fix the count — this is exactly the kind of unbacked claim `CLAUDE.md` says to correct on sight.
- Lines 215–216 describe `gnomarchy keybindings` as a searchable list. Say it opens the control center, that bindings can now be changed there, and that `--list` is still plain text.

- [ ] **Step 2: Update the manual pages**

- `manual/07-the-menu.md`: describe the three pages, the sidebar, and the keyboard model from the spec's table (`Ctrl+1/2/3`, `/`, `Ctrl+F`, `Enter`, `Esc`, `?`).
- `manual/03-keybindings.md`: document that shortcuts can be rebound from the Keybindings page, that a conflict is reported with the action that holds the key, that `Backspace` unbinds, and that "Reset to layout defaults" re-applies `gnomarchy keymap`.

Keep both within the renderable subset — no tables, links, images or blockquotes. Task 11's checker enforces this.

- [ ] **Step 3: Document the GUI in AGENTS.md and CLAUDE.md**

Add a short section to both describing `gui/` — that it is GJS with no build step, that `gui/src/lib/*.js` must stay free of `gi://` imports so the Node tests keep working, and that `gui/` must never move under `bin/` because `symlinks.sh` publishes everything there as a command.

- [ ] **Step 4: Verify the manual still renders**

Run: `node iso/tests/verify-manual-subset.js manual`
Expected: `PASS  every manual page is within the renderable subset`.

- [ ] **Step 5: Run every test once more**

Run: `node --test gui/tests/`
Expected: all suites pass — accel (6), markdown (10), themes (6), manual (5), conflicts (4).

- [ ] **Step 6: Commit**

```bash
git add README.md AGENTS.md CLAUDE.md manual/
git commit -m "docs: describe the control center in the README, manual and agent guides"
```

---

## Final verification

Before opening a pull request:

- [ ] `node --test gui/tests/` — every suite passes
- [ ] `node iso/tests/verify-manual-subset.js manual` — passes
- [ ] `bash -n` over every bash file this plan touched — all parse
- [ ] `git status --short` is empty and `git diff --stat main...HEAD` shows only intended files
- [ ] The app launches under WSL on each of the three pages without a traceback
- [ ] `git ls-files -s install/helpers/gui.sh install/config/control-center.sh migrations/2026-09-12-1200-control-center-gui.sh iso/tests/verify-manual-subset.js` shows mode `100755` for all four — otherwise the installer's `chmod +x` dirties the tree and blocks the next `git pull`

Then open the PR and let the ISO smoke test run. **Per `CLAUDE.md`, cut a release only from a commit where that job is green** — the release workflow only proves the ISO builds, and five releases shipped installation defects through green builds.
