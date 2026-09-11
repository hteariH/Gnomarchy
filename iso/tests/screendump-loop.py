#!/usr/bin/env python3

"""Photograph a running QEMU guest on a timer, over QMP.

This exists because the guest cannot photograph itself. GNOME Shell answers
org.gnome.Shell.Screenshot only for an allowlist of senders it ships with, so
a script in the session gets AccessDenied no matter what it does. QEMU has no
such opinion: screendump writes whatever the virtual display is showing.

Frames land as PPM and are converted later; a frame identical to the one
before it is dropped, because a desktop holding still for twelve seconds would
otherwise produce a pile of copies. Each kept frame is recorded in an index
with the wall-clock time it was taken, which is what pairs it with the stage
timestamps the in-guest script writes into its transcript.

Usage:
  screendump-loop.py SOCKET OUTDIR LABEL INTERVAL MAX_SECONDS
"""

import hashlib
import json
import os
import socket
import sys
import time


def read_reply(stream):
    """Read QMP lines until one is a reply rather than an asynchronous event."""
    while True:
        line = stream.readline()
        if not line:
            return None
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "event" in message:
            continue
        return message


def connect(sock_path, appear_timeout=180):
    deadline = time.time() + appear_timeout
    while not os.path.exists(sock_path):
        if time.time() > deadline:
            print("screendump-loop: QMP socket never appeared at %s" % sock_path,
                  file=sys.stderr)
            return None, None
        time.sleep(1)

    # The socket can exist a moment before QEMU is listening on it.
    last_error = None
    while time.time() < deadline:
        try:
            conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            conn.connect(sock_path)
            break
        except OSError as exc:
            last_error = exc
            time.sleep(1)
    else:
        print("screendump-loop: could not connect: %s" % last_error, file=sys.stderr)
        return None, None

    stream = conn.makefile("rw", encoding="utf-8", newline="\n")
    stream.readline()  # greeting
    stream.write(json.dumps({"execute": "qmp_capabilities"}) + "\n")
    stream.flush()
    if read_reply(stream) is None:
        print("screendump-loop: QMP handshake failed", file=sys.stderr)
        return None, None
    return conn, stream


def main():
    if len(sys.argv) != 6:
        print(__doc__, file=sys.stderr)
        return 2

    sock_path, outdir, label = sys.argv[1], sys.argv[2], sys.argv[3]
    interval = float(sys.argv[4])
    max_seconds = float(sys.argv[5])

    os.makedirs(outdir, exist_ok=True)
    conn, stream = connect(sock_path)
    if conn is None:
        return 1

    index_path = os.path.join(outdir, "%s-index.txt" % label)
    index = open(index_path, "w", encoding="utf-8", newline="\n")

    started = time.time()
    kept = 0
    attempts = 0
    previous_digest = None

    while time.time() - started < max_seconds:
        attempts += 1
        frame = os.path.abspath(os.path.join(outdir, "%s-%04d.ppm" % (label, kept)))
        taken_at = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        try:
            stream.write(json.dumps({
                "execute": "screendump",
                "arguments": {"filename": frame},
            }) + "\n")
            stream.flush()
            reply = read_reply(stream)
        except (BrokenPipeError, ConnectionResetError, OSError):
            print("screendump-loop: QEMU went away after %d attempts" % attempts)
            break

        if reply is None:
            print("screendump-loop: QEMU closed the monitor after %d attempts" % attempts)
            break
        if "error" in reply:
            print("screendump-loop: screendump refused: %s" % reply["error"])
            time.sleep(interval)
            continue

        if not os.path.exists(frame) or os.path.getsize(frame) == 0:
            time.sleep(interval)
            continue

        with open(frame, "rb") as handle:
            digest = hashlib.sha256(handle.read()).hexdigest()

        # A desktop holding still repeats itself; keep only what changed.
        if digest == previous_digest:
            os.unlink(frame)
        else:
            previous_digest = digest
            index.write("%s  %s\n" % (taken_at, os.path.basename(frame)))
            index.flush()
            kept += 1

        time.sleep(interval)

    index.close()
    print("screendump-loop: %d distinct frames from %d attempts over %.0fs"
          % (kept, attempts, time.time() - started))
    return 0


if __name__ == "__main__":
    sys.exit(main())
