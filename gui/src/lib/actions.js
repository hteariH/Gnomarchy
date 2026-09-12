// Running the gnomarchy commands.
//
// Three shapes, because the actions are not alike: fire-and-forget, streams
// output into a pane, and "get the window out of the way first" (the capture
// actions, which the bash menu handled by exec'ing over its own terminal).

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Adw from 'gi://Adw?version=1';

// Gio.Subprocess.new spawns directly with no shell, so a missing executable
// (gnomarchy-update not on PATH, say) throws synchronously instead of
// producing a "command not found" line on stdout -- there is no shell left to
// print one. Every caller below needs to tell "spawned, and its own exit
// status is the caller's business" apart from "never spawned at all", so that
// lives here once.
function trySpawn(argv, flags) {
  try {
    return { process: Gio.Subprocess.new(argv, flags), error: null };
  } catch (error) {
    return { process: null, error };
  }
}

export function run(argv) {
  const { process, error } = trySpawn(argv, Gio.SubprocessFlags.NONE);
  if (error !== null) {
    // No output pane and no dialog for this shape (it backs fire-and-forget
    // actions like Lock/Suspend/reset-keybindings) -- logError at least keeps
    // this out of a signal handler and visible via journalctl, rather than
    // swallowed.
    logError(error, `Failed to run: ${argv.join(' ')}`);
    return;
  }
  // Reap it rather than leaving a zombie; failures from here on are reported
  // by the command itself, which has a better message than anything we could
  // invent.
  process.wait_async(null, null);
}

export function runForOutput(argv, onLine, onDone) {
  const { process, error } = trySpawn(
    argv,
    Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_MERGE,
  );
  if (error !== null) {
    // Report it through the same callbacks a failed command would use, so the
    // output pane shows why instead of sitting empty forever.
    onLine(`Could not run ${argv.join(' ')}: ${error.message}`);
    onDone(false);
    return;
  }

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

function presentSpawnError(window, argv, error) {
  const dialog = new Adw.AlertDialog({
    heading: 'Could not run this',
    body: `${argv.join(' ')}\n${error.message}`,
  });
  dialog.add_response('close', 'Close');
  window.trackDialog(dialog);
  dialog.present(window);
}

export function runAndQuit(window, argv) {
  // Spawn before touching the window: hiding it first and only then finding
  // out the command never started left a live process with a permanently
  // invisible window (GtkApplication had no visible window to quit, so
  // single-instance reuse kept handing that same dead window back on every
  // later hotkey press). Now the window stays up and visible on failure.
  const { process, error } = trySpawn(argv, Gio.SubprocessFlags.NONE);
  if (error !== null) {
    presentSpawnError(window, argv, error);
    return;
  }
  // Reap it rather than leaving a zombie.
  process.wait_async(null, null);

  window.set_visible(false);
  // Give the compositor a moment to take the window down before the capture
  // tool grabs the screen, or the control center appears in the screenshot.
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 250, () => {
    window.close();
    return GLib.SOURCE_REMOVE;
  });
}
