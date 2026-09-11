# CLAUDE.md

Guidance for Claude Code working in this repository.

## What this is

Gnomarchy is an Arch Linux distribution: Omarchy's tooling and rolling base
with a tuned GNOME 50 desktop instead of Hyprland. It ships as an installable
ISO and as a config repository that lives at `~/.local/share/gnomarchy` on
installed machines.

Two things follow from that and shape everything else:

1. **Editing a file here only affects new installs.** Machines already running
   need a migration. See *Migrations*.
2. **The installer runs inside `arch-chroot`**, where there is no D-Bus session
   bus. Anything that writes to dconf is discarded there. See *The chroot
   boundary*.

## Layout

```
bin/                     the gnomarchy CLI; one file per subcommand
install/
  preflight/             guards, pacman setup (enables multilib)
  packaging/             package installation
  config/                system and user configuration
    hardware/            per-vendor profiles, sourced by all.sh
  desktop/               GNOME configuration (dconf; needs a session)
  login/                 GDM, Plymouth, limine + snapper
  post-install/          cleanup, migration baseline
  gnomarchy-base.packages   pacman list, official repos only
migrations/              timestamped, once-per-machine repair scripts
themes/                  22 themes; alacritty.toml is the canonical palette
manual/                  numbered pages read by `gnomarchy manual`
iso/
  builder/build-iso.sh   archiso profile assembly
  configs/airootfs/root/.automated_script.sh   the installer itself
  tests/                 smoke-test verification scripts
default/                 files deployed onto the installed system
```

`install.sh` sources the stages in order and wraps each in `run_stage`, which
prints `STAGE START` / `STAGE OK` markers into the install log.

## The chroot boundary

This is the single most important thing to understand here.

The ISO installer runs `install.sh` under `arch-chroot -u $USERNAME`. In that
context:

- `gsettings` writes go nowhere. dconf needs a session bus.
- **Custom keybindings cannot be expressed as gschema overrides** — they live at
  relocatable dconf paths — so they have no fallback at all.
- `systemctl enable` works (it is offline symlink manipulation).
- Package installation, file deployment and udev rules work.

So the rule is:

| Work | Where it goes |
|---|---|
| packages, files, udev, systemd enablement | `install/` stages |
| anything touching dconf, PipeWire or the seat | `gnomarchy-first-run` |

`install/desktop/all.sh` checks `gnomarchy_can_write_dconf` and, when there is
no session, writes an autostart entry instead of configuring anything.

### The autostart entry must not declare a phase

GNOME 50 runs XDG autostart through `systemd-xdg-autostart-generator`, which
**skips any entry containing `X-GNOME-Autostart-Phase`** because phases cannot
be expressed as units. Setting it silently stopped first-run from ever
executing — the cause of fresh installs having no keyboard shortcuts, a dock in
the default position and an unthemed terminal. Do not add it back.

## Migrations

`migrations/<YYYY-MM-DD-HHMM>-<slug>.sh`, applied exactly once per machine,
recorded in `~/.local/state/gnomarchy/migrations.log`. `gnomarchy update` runs
pending ones after the git pull; `install/post-install/migrations-baseline.sh`
marks them all applied on a fresh install rather than replaying them.

They must be **idempotent** — they may run on a machine in any prior state.

If a change alters behaviour on an existing machine, it needs one. Adding a
package to `gnomarchy-base.packages` alone reaches new installs only.

## Conventions

- `#!/bin/bash`, `[[ ]]` for strings, `(( ))` for arithmetic, `$HOME` never a
  hardcoded path.
- Helpers from `install/helpers/presentation.sh`: `gnomarchy_header`,
  `gnomarchy_step`, `gnomarchy_warn`, `gnomarchy_error`, `gnomarchy_substep`.
  `gnomarchy_error` only prints — add an explicit `exit` if you mean to stop.
- New `bin/gnomarchy-*` commands need a case in `bin/gnomarchy` **and** they are
  symlinked into `/usr/local/bin` by `install/config/symlinks.sh`. Without that
  symlink the GNOME session cannot find them; it does not read your shell
  profile.
- Files created on a non-Unix host land in git as mode 100644. Run
  `git update-index --chmod=+x` on new scripts, or the installer's `chmod +x`
  will dirty the tree and block the next `git pull`.

### Do not suppress errors by default

Five separate defects shipped because a failure was hidden behind `2>/dev/null`
or `|| true`: extension schemas never compiled, Brave binaries left
non-executable, the git checkout never created, the install log never written,
`gnomarchy update` reporting success after a failed pull.

Suppress output only where failure genuinely does not matter, and say so in a
comment. Prefer reporting and continuing over silence.

## Verifying package names

`pacman -S` is all-or-nothing: one unknown name aborts the transaction and,
under `set -e`, the installer. A release once shipped unable to install because
of `whisper.cpp` — the package is `whisper-cpp`.

Check names against the real databases before adding them:

```bash
curl -sSL "https://archlinux.org/packages/search/json/?name=<pkg>"
curl -sSL "https://aur.archlinux.org/rpc/v5/info?arg[]=<pkg>"
```

`gnomarchy-base.packages` must contain only official-repo packages; AUR belongs
in an opt-in command with an AUR helper and a fallback.

`install/packaging/base.sh` now partitions the list against the sync databases
and skips unresolvable names with a warning rather than failing.

## Verification

`.github/workflows/install-smoke-test.yml` builds the ISO, **installs from it in
QEMU** and checks the result in two layers:

- `iso/tests/verify-install.sh` — offline, against the mounted image
- `iso/tests/verify-session.sh` — inside a real autologin GNOME session

Every check corresponds to a defect that once shipped. Add one when you fix
something the test would not have caught.

**Cut a release only from a commit where this job is green.** The release
workflow only proves the ISO builds; five releases shipped installation
defects through green builds.

### Mounting the installed image

The filesystem is split. Mounting less than this silently empties directories
and turns every check against them into a false failure — it happened three
times:

```
/dev/nbd0p3  subvol=@         /
/dev/nbd0p3  subvol=@home     /home
/dev/nbd0p3  subvol=@var_log  /var/log
/dev/nbd0p2                   /boot     (EFI partition, holds limine.conf)
```

Also: absolute symlinks inside a mounted image resolve against the **host**
filesystem, so `-e` is false however correct the link is. Test with `-L`.

### Driving the installer unattended

Answers are read from a file on a device labelled `GNOMARCHY`, so the ISO under
test stays byte-identical to the one that ships. FAT labels are capped at 11
characters.

```bash
printf '%s\n' 'GNOMARCHY_DISK=/dev/vda' 'GNOMARCHY_USERNAME=citest' \
  'GNOMARCHY_PASSWORD=test' 'GNOMARCHY_ENCRYPT=n' > gnomarchy-unattended.conf
truncate -s 8M answers.img && mkfs.vfat -n GNOMARCHY answers.img
mcopy -i answers.img gnomarchy-unattended.conf ::/
```

## Diagnosing a failure

```bash
/var/log/gnomarchy-install.log        installation; STAGE markers show where it stopped
journalctl --user -t gnomarchy-first-run    desktop configuration
journalctl --user -t gnomarchy-verify       the CI session check
gnomarchy version --verbose           version, theme, migrations applied
```

The install log is written by `install.sh` teeing into it. Before that existed,
the installer told users to read a file that was always empty.

## The theme engine

`gnomarchy-theme-set` is the only thing that should write these:

```
~/.config/alacritty/colors.toml
~/.config/btop/themes/current.theme
~/.config/nvim/lua/plugins/theme.lua
~/.config/nvim/lua/plugins/gnomarchy-colorscheme.lua
~/.config/gtk-{3,4}.0/gnomarchy-theme.css
```

Each theme's `alacritty.toml` is the canonical palette: GNOME Terminal's dconf
colours and the GTK CSS are both generated from it.

The LazyVim colorscheme pin matters — without it LazyVim applies its own
default after the theme spec runs and silently undoes the switch.

GNOME Terminal keeps colours in dconf, not a file, which is why a fixed profile
UUID (`b1dcc9dd-…`) is created at install time.

## Documentation is a claim about the code

The README described VS Code theming, Framework and ROG support, a 25 MB video
compression target and 4K bundled wallpapers. None of it existed. If you change
behaviour, change the README, `AGENTS.md` and the relevant `manual/` page in the
same commit — and if you find a claim nothing backs, either implement it or
remove it rather than leaving it.

## Things deliberately not done

- Wallpapers are downloaded at install time, not committed. Omarchy ships no
  attribution for them and the only source it names is unlicensed; see
  `BACKGROUNDS.md`.
- GDM is themed through its dconf profile, not by patching gresource bundles,
  which breaks on every GNOME update.
- `grep`, `find` and `cat` are not aliased to ripgrep, fd and bat.
