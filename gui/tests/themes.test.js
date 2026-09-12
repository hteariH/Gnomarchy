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
