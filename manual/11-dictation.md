# Dictation

Press `Super + D` to start, press it again to stop. The transcription is typed
into whatever window has focus.

```bash
gnomarchy voxtype toggle
gnomarchy voxtype status
```

## How it works

Recording goes to a temporary file and is transcribed by `whisper-cli` from the
`whisper-cpp` package, running entirely on your machine. Nothing is uploaded
and there is no account or API key.

The model (`base.en`, about 140 MB) is downloaded on first use and cached in
`~/.local/share/gnomarchy/models/`.

## Requirements

- `whisper-cpp`, installed as part of the base package set
- `ydotoold` running, so the text can be typed into the focused window
- Your user in the `input` group - this needs one log out and back in after
  installation

If dictation reports success but nothing is typed, `ydotoold` is the usual
culprit:

```bash
systemctl status ydotoold
groups | grep input
```
