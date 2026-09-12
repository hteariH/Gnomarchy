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
