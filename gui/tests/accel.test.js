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
