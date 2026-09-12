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
