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
