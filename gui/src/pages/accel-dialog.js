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
