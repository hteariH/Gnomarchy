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
