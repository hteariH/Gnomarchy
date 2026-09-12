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
