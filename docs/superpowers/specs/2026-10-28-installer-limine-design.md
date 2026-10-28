# Installer, Limine and bootable snapshots

A gum-based text installer, Limine as the bootloader of the installed system,
and snapper snapshots that appear in the boot menu and can be booted and
restored — the CachyOS experience, built from official packages and our own
bash.

Status: design approved, not yet implemented.
Branch: `feat/installer-limine`.

## Why

What ships today promises more than it does.

| Claim or expectation | Reality |
|---|---|
| README: snapshots appear in the Limine menu | nothing writes snapshot entries; `site/app.js` admits it |
| `install/login/limine-snapper.sh` creates a snapper config | `create-config` needs D-Bus and an unmounted `/.snapshots`; it fails behind `2>/dev/null \|\| true` |
| it enables `snap-pac.timer` | no such unit exists |
| LUKS installs boot | the `encrypt` hook is inserted into a systemd initramfs and no `cryptdevice=` is passed |
| Plymouth is in the initramfs | `plymouth.sh` inserts after `udev`, which a systemd HOOKS line never contains |
| Limine stays current | nothing redeploys its EFI binary when the package updates |
| bootloader installation is checked | every command in it is suppressed and CI has no Limine check |

The installer itself is a sequence of `read` prompts with no disk list, no
summary before the disk is wiped and no way to see what failed.

## Scope

**In.**

- A gum text installer on tty1: disk list, form (name, user, password,
  hostname, timezone, keyboard layout, encryption), summary, staged progress,
  failure screen.
- `gnomarchy-boot`, the one program that writes `limine.conf`.
- Snapshots via snapper and snap-pac, listed in the Limine menu, bootable
  read-only with a volatile overlay, restorable with `gnomarchy snapshot
  restore`.
- Limine colours follow the active Gnomarchy theme.
- Fixes for every defect in the table above.
- Fast pre-ISO tests, new offline and in-session checks, a third QEMU boot
  from a snapshot, and an encrypted-install matrix entry.

**Out.**

- Manual partitioning, dual boot, installing alongside another OS. The
  installer takes a whole disk.
- Locale selection. The system stays `en_US.UTF-8`.
- The live ISO's own boot (syslinux / systemd-boot). Unchanged.
- AUR tooling (limine-snapper-sync, limine-mkinitcpio-hook). Rejected:
  AUR-only, and the former needs a GraalVM build.
- A wallpaper in the Limine menu.
- Migrations. No machine runs an affected release yet.

## Part 1 — Boot and snapshots

### Where the code lives

Sources sit in `default/boot/` in the repository. Root must never execute
scripts from a user's home, so `install/login/boot.sh` deploys them root-owned:

| Source | Installed as |
|---|---|
| `default/boot/gnomarchy-boot` | `/usr/local/lib/gnomarchy/boot/gnomarchy-boot` |
| `default/boot/lib/*.sh` | `/usr/local/lib/gnomarchy/boot/lib/` |
| `default/boot/50-gnomarchy-boot` | `/usr/lib/snapper/plugins/50-gnomarchy-boot` |
| `default/boot/95-gnomarchy-boot.hook` | `/etc/pacman.d/hooks/95-gnomarchy-boot.hook` |
| `default/boot/95-gnomarchy-limine.hook` | `/etc/pacman.d/hooks/95-gnomarchy-limine.hook` |
| `default/boot/gnomarchy-overlay` | `/etc/initcpio/install/gnomarchy-overlay` |
| `default/boot/mkinitcpio.conf` | `/etc/mkinitcpio.conf.d/gnomarchy.conf` |
| `default/boot/gnomarchy-boot-theme.{path,service}` | `/etc/systemd/system/` |
| `default/boot/snapper-root.conf` | `/etc/snapper/configs/root` (first deploy only) |
| `default/boot/snapshot-notify.desktop` | `/etc/xdg/autostart/gnomarchy-snapshot-notify.desktop` |

`boot.sh` is idempotent. It runs in three places:

- from the ISO installer right after base configuration;
- from `install.sh`'s login stage, where it finds everything already in place;
- from `gnomarchy update` after the pull, so root-owned copies follow the
  repository.

It replaces `install/login/limine-snapper.sh`, which is deleted.

### Machine state

| File | Content | Written by |
|---|---|---|
| `/etc/kernel/cmdline` | base kernel command line | installer |
| `/etc/gnomarchy/boot.conf` | `DISK=`, `ESP=/boot`, `FIRMWARE=uefi\|bios` | installer |
| `/etc/gnomarchy/boot-theme.conf` | theme palette, mode 0664 `root:wheel` | `gnomarchy-theme-set` |
| `/boot/gnomarchy/store/<b2sum>` | content-addressed kernels and initramfs images | `gnomarchy-boot` |
| `/boot/gnomarchy/entries/<N>.conf` | snapshot N: kernel name, kernel hash, initramfs hash, version, date, description | `gnomarchy-boot` |

`limine.conf` is always generated from these and the kernels in `/boot`; it is
never edited in place.

### `gnomarchy-boot`

Runs as root. All writes to the ESP happen under `flock /boot/gnomarchy/lock`.
`limine.conf` is written to a temporary file on the ESP, synced and renamed.

| Subcommand | Does |
|---|---|
| `install` | copies `/usr/share/limine/BOOTX64.EFI` to `EFI/BOOT/BOOTX64.EFI` (fallback path) and `EFI/limine/BOOTX64.EFI`, creates or keeps an NVRAM entry `Gnomarchy` with `efibootmgr`, copies `limine-bios.sys` to the ESP root and runs `limine bios-install $DISK`. Hybrid always, in either firmware mode: the disk has a BIOS boot partition and becomes bootable both ways. A failed NVRAM write warns and continues — the fallback path still boots. |
| `update [--default ID]` | regenerates `limine.conf`; ID is `snapshot:N` or a kernel name such as `linux` |
| `snapshot-add N` | records snapshot N (below), then `update` |
| `snapshot-remove N` | drops entry N, garbage-collects `store`, then `update` |
| `restore N [--yes]` | restores snapshot N (below) |

Every failure is reported on stderr and gives a non-zero exit. Nothing is
suppressed.

#### Generated menu

```
timeout: 3
default_entry: Gnomarchy/linux
interface_branding: Gnomarchy
interface_branding_colour: <theme blue>
term_palette: <8 normal colours>
term_palette_bright: <8 bright colours>
term_background: <theme background, TT=00>
term_foreground: <theme foreground>

/+Gnomarchy
//linux
    protocol: linux
    kernel_path: boot():/vmlinuz-linux#<b2sum>
    module_path: boot():/initramfs-linux.img#<b2sum>
    kernel_cmdline: <contents of /etc/kernel/cmdline>
//linux (fallback)                  # only if initramfs-linux-fallback.img exists
//Snapshots
///12 │ 2026-10-28 14:02 │ pacman -Syu
    protocol: linux
    kernel_path: boot():/gnomarchy/store/<b2sum>#<b2sum>
    module_path: boot():/gnomarchy/store/<b2sum>#<b2sum>
    kernel_cmdline: <snapshot command line>
```

- One `//<kernel>` entry per `/boot/vmlinuz-*` with a matching initramfs, so
  `linux-lts` and others work without changes.
- Microcode is not a separate module: `microcode` is in HOOKS and lands in the
  initramfs.
- Snapshots are listed newest first.
- `--default ID` writes `default_entry` as a Limine entry path, for example
  `Gnomarchy/Snapshots/12 │ …`, escaping `/`, `\` and `#` as Limine
  requires. Without it the default is `Gnomarchy/linux`. It is always written
  explicitly: Limine's implicit default, index 1, is the `Gnomarchy`
  directory, and a directory disables autoboot.
- When `boot-theme.conf` is missing or any value in it fails `^[0-9a-fA-F]{6}$`,
  the theme lines are omitted with a warning. The file is group-writable by
  wheel, so it is parsed as data and nothing else.

#### Snapshot command line

Derived from `/etc/kernel/cmdline`:

- `rw` becomes `ro`;
- `rootflags=subvol=@` becomes `rootflags=subvol=@snapshots/N/snapshot`;
- `splash` is dropped;
- `systemd.volatile=overlay gnomarchy.snapshot=N` is appended.

A base command line without `rootflags=subvol=@` is an error, not a guess.

#### Adding a snapshot

`snapshot-add N` reads `/.snapshots/N/info.xml` for date, description and type.
The snapper plugin must not call snapper, so this is the only source.

It takes the kernel and initramfs currently on the ESP. Their version must
have a `usr/lib/modules/<version>` directory inside the snapshot; otherwise
the entry is skipped and the reason logged. The version comes from
`file -bL` on the kernel image.

This gives each snapshot the right kernel without tracking kernels
separately:

- snap-pac's pre snapshot runs before the transaction, when the ESP still holds
  the old kernel;
- its post snapshot runs after `90-mkinitcpio-install.hook`, when the ESP
  holds the new one;
- a manual snapshot matches the running system.

Files are copied into `store` under their b2sum, so ten snapshots of one
kernel cost one copy. Hashing reuses a cached digest when size and mtime are
unchanged, which keeps the plugin within snapper's few-second budget.

**ESP budget.** If ESP usage would exceed 80%, entries for the oldest
snapshots are dropped from the menu until it fits. The snapshots themselves
stay and remain restorable from a running system.

### snapper and snap-pac

- `/etc/snapper/configs/root` is written from snapper's template
  (`/usr/share/snapper/config-templates/default`) with:
  - `TIMELINE_CREATE="no"`;
  - `NUMBER_LIMIT="10"`, `NUMBER_LIMIT_IMPORTANT="5"`;
  - `ALLOW_GROUPS="wheel"`.
- `SNAPPER_CONFIGS="root"` goes in `/etc/conf.d/snapper`.
- Nothing needs D-Bus, so it works inside arch-chroot. `/.snapshots` is
  already the `@snapshots` subvolume, which `create-config` would refuse.
- `snapper-cleanup.timer` is enabled; the timeline timer is not.
- `snap-pac` (extra) is installed **last** in the installation, after the
  config exists. Installed earlier, every pacman transaction in `install.sh`
  would leave a snapshot pair.
- `50-gnomarchy-boot` handles three events and ignores the rest:
  - `create-snapshot-post root` → `snapshot-add`;
  - `delete-snapshot-post root` → `snapshot-remove`;
  - `create-config-post` → `update`.

  Snapper's plugin interface is a stable shell interface in
  `/usr/lib/snapper/plugins/`. Snapper treats a non-zero exit as an error and
  reports it, which is the behaviour we want.

### pacman hooks

| Hook | Trigger | Runs |
|---|---|---|
| `95-gnomarchy-boot.hook` | kernel images, `usr/lib/initcpio/*`, mkinitcpio | `gnomarchy-boot update` (after `90-mkinitcpio-install.hook`) |
| `95-gnomarchy-limine.hook` | the `limine` package | `gnomarchy-boot install` then `update` |

### initramfs

`/etc/mkinitcpio.conf.d/gnomarchy.conf`:

```
HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck gnomarchy-overlay)
```

- `sd-encrypt` is present only on encrypted installs. The installer and
  `boot.sh` write the line from `/etc/gnomarchy/boot.conf`.
- `install/login/plymouth.sh` stops editing HOOKS.
- `gnomarchy-overlay` adds `systemd-volatile-root.service` and the `overlay`
  module. The systemd install hook does not include either, so
  `systemd.volatile=overlay` would do nothing without it.

### LUKS

- `/etc/kernel/cmdline` carries `rd.luks.name=<luks-uuid>=cryptroot` and
  `root=UUID=<btrfs-uuid>`.
- No crypttab entry for the root. The broken `encrypt` sed is removed.

### Booting a snapshot

- The root is the read-only snapshot under a tmpfs overlay. Changes vanish on
  reboot.
- `/home`, `/var/log` and `/var/cache` come from fstab as usual and stay
  persistent.
- fstab must not contain `subvolid=`. The installer strips it after
  `genfstab`, so mounts by name work whichever subvolume is the root.
- `/etc/xdg/autostart/gnomarchy-snapshot-notify.desktop` runs
  `gnomarchy snapshot notify`. That exits silently without
  `gnomarchy.snapshot=` on the command line. Otherwise it sends a notification
  "Booted snapshot N — changes will not be kept" with a **Restore** action that
  opens a terminal on `gnomarchy snapshot restore N`.
- The entry declares no `X-GNOME-Autostart-Phase`; see CLAUDE.md.
- libnotify is already in the base list.

### Restore

`gnomarchy snapshot restore [N]` (new `bin/gnomarchy-snapshot-restore`, user
side):

- Without N it offers a `gum choose` over `snapper -c root list`.
- It asks for confirmation, then runs `sudo
  /usr/local/lib/gnomarchy/boot/gnomarchy-boot restore N`.

The root side does:

1. Mount the top-level subvolume (`subvolid=5`) of the root filesystem at
   `/run/gnomarchy/btrfs-top`.
2. Delete any previous `@restore-backup-*`, including nested subvolumes
   (systemd creates `var/lib/machines` and `var/lib/portables` as
   subvolumes). Keep one backup.
3. Rename `@` to `@restore-backup-<YYYYmmdd-HHMM>`. This works whether `@` is
   mounted as the root or not.
4. `btrfs subvolume snapshot @snapshots/N/snapshot @` — a writable copy.
5. Copy snapshot N's kernel and initramfs from `store` back to
   `/boot/vmlinuz-<kernel>` and `/boot/initramfs-<kernel>.img`, so the restored
   modules match.
6. Run `update`, unmount, and offer a reboot on the user side.

Restoring from a normal boot and from a snapshot boot are the same operation.

### Theme

- `gnomarchy-theme-set` writes these keys from the theme's `alacritty.toml`
  into `/etc/gnomarchy/boot-theme.conf`: `BACKGROUND`, `FOREGROUND`,
  `NORMAL_0..7`, `BRIGHT_0..7`, `ACCENT` (normal blue).
- The file is `root:wheel 0664`, created by `boot.sh`; the theme engine needs no
  sudo for it.
- `gnomarchy-boot-theme.path` watches the file, and its service runs
  `gnomarchy-boot update` as root.
- `boot-theme.conf` joins the list of files only `gnomarchy-theme-set` writes.

## Part 2 — Installer

### Structure

- `iso/installer/gnomarchy-install` with `iso/installer/lib/`:
  - `ui.sh` — screens, plain-output fallback;
  - `form.sh` — fields and validation;
  - `disk.sh` — disk listing, partitioning, LUKS, Btrfs;
  - `stages.sh` — the seven stages;
  - `keymaps.tsv` — the layout table.
- The ISO build already copies the repository to `/root/gnomarchy`, so the
  installer always matches the configuration it installs.
- `iso/configs/airootfs/root/.automated_script.sh` shrinks to an entry point:
  on tty1 only, it executes `/root/gnomarchy/iso/installer/gnomarchy-install`.
- `set -Eeuo pipefail` and an `ERR` trap route every failure to the failure
  screen. All `2>/dev/null || true` in the current installer goes.
- UI strings are English, like the rest of the system.

### Interactive screens

1. **Welcome.**
   - Banner, firmware mode, network check (`pacstrap` needs one).
   - Without a network: *Retry*, *Configure Wi-Fi* (`iwctl`), *Exit*.
2. **Disk.** `gum choose` over `lsblk -dnbo NAME,SIZE,MODEL,TRAN`.
   - Excluded: loop, rom, zram and the device holding `/run/archiso/bootmnt`.
   - Disks under 20 GiB are refused with the reason.
3. **Form.** Fields follow one another, each validated on entry.

   | Field | Input | Rule / default |
   |---|---|---|
   | Full name | `gum input` | optional |
   | Username | `gum input` | `^[a-z_][a-z0-9_-]{0,31}$`, not `root` |
   | Password | `gum input --password`, twice | non-empty, must match |
   | Hostname | `gum input` | RFC 1123 label, default `gnomarchy` |
   | Timezone | `gum filter` over `timedatectl list-timezones` | default `UTC` |
   | Keyboard | `gum filter` over `keymaps.tsv` | default `us` |
   | Encrypt | `gum confirm` | default no |
   | Disk password | "use the same password?", else twice | only if encrypting |

4. **Summary.**
   - A bordered `gum style` block: disk (model, size), layout (BIOS boot
     1 MiB, ESP 4 GiB, Btrfs on the rest, LUKS yes or no), user, hostname,
     timezone, keyboard.
   - A red line: "All data on /dev/X will be erased."
   - Choices: *Install*, *Edit* (back to the form with answers kept), *Exit*.
5. **Progress.** Seven stages with ✓ / spinner / ✗:
   1. Partition disk
   2. Create filesystems
   3. Install base system (pacstrap)
   4. Configure system
   5. Install bootloader
   6. Install Gnomarchy desktop
   7. First snapshot and cleanup

   - All output goes to `/var/log/gnomarchy-installer.log`.
   - The screen shows the stage list and the log's last line.
   - Under stage 6 it shows the `install.sh` sub-stage, parsed from its
     `STAGE START` markers.
6. **Failure.**
   - The failed stage and the last 30 log lines.
   - Choices: *Full log* (`gum pager`), *Shell*, *Power off*.
   - Never reboots on its own.
7. **Done.** "Remove the installation medium", then a reboot confirmation.

### Keyboard layouts

`keymaps.tsv` is a curated table of about 25 rows: X11 layout, X11 variant,
console keymap, console font, label. Example: `ru`, `''`, `ru`, `cyr-sun16`,
`Russian`. The choice is written to:

- `/etc/vconsole.conf` — `KEYMAP=`, `FONT=`. `sd-vconsole` puts both into the
  initramfs, so a LUKS password is typed in the chosen keymap. Every console
  keymap in the table must default to its Latin layer. The test checks this
  by reading the plain mapping of keycode 16 (Q) from the keymap file.
- `/etc/X11/xorg.conf.d/00-keyboard.conf` — GDM and X11 apps.
- `/etc/gnomarchy/keyboard.conf` — read by `gnomarchy-first-run`, which sets
  `org.gnome.desktop.input-sources sources`. This is dconf, so it cannot
  happen in the chroot. For a non-Latin layout `us` is added first, so Latin
  input and shortcuts keep working.

### Unattended mode

- **Trigger.** Unchanged: `gnomarchy-unattended.conf` on the boot medium or on
  a device labelled `GNOMARCHY`.
- **Output.** No gum. Plain `[3/7] Install base system` lines, and the full
  stream goes to both the console (serial in CI) and the log.
- **Variables.**
  - Existing: `GNOMARCHY_DISK`, `GNOMARCHY_FULLNAME`, `GNOMARCHY_USERNAME`,
    `GNOMARCHY_PASSWORD`, `GNOMARCHY_ENCRYPT`.
  - New, all optional: `GNOMARCHY_HOSTNAME` (default `gnomarchy`),
    `GNOMARCHY_TIMEZONE` (`UTC`), `GNOMARCHY_KEYMAP` (`us`; a `keymaps.tsv`
    key), `GNOMARCHY_DISK_PASSWORD` (default: the user password).
- **Validation.** The same functions as the form. A missing or invalid
  required value is an error and an exit, never a prompt, so CI cannot hang.

### Installation order

Changes from today are in **bold**.

1. **Partition.** wipefs; GPT with BIOS boot 1 MiB, ESP **4 GiB**, root.
2. **Filesystems.**
   - Optional LUKS2 (argon2id) opened as `cryptroot`.
   - Btrfs with `@`, `@home`, `@snapshots`, `@var_log`, `@var_cache`,
     mounted with today's options.
3. **Base system.**
   - `pacstrap -K` as today.
   - `genfstab -U`, **then strip `subvolid=`**.
4. **Configure** (in chroot, as root).
   - **Timezone, hostname and `/etc/hosts`, keyboard files**; locale as today.
   - User and passwords.
   - **Copy the repository to the user's `~/.local/share/gnomarchy` now**,
     rather than after the chroot step.
   - **Write `/etc/kernel/cmdline`, `/etc/gnomarchy/boot.conf` and the
     mkinitcpio drop-in**, then `mkinitcpio -P`.
5. **Bootloader.**
   - **`install/login/boot.sh`**, which runs `gnomarchy-boot install` and
     `update`.
   - From here the disk boots to a console even if stage 6 fails.
6. **Desktop.** `install.sh` under `arch-chroot -u` with
   `GNOMARCHY_CHROOT_INSTALL=1`, as today.
7. **Snapshot and cleanup.**
   - **In chroot as root: write the snapper config, install snap-pac, create
     snapshot 1 "Gnomarchy installed"** with `snapper --no-dbus`. The plugin
     runs in the client and adds the menu entry.
   - Remove the temporary sudoers file.
   - **Copy the installer log to the target.**
   - Unmount.

## Part 3 — Tests, CI, documentation

### Fast tests before the ISO build

A new `unit` job in `install-smoke-test.yml` runs in an archlinux container.
The ISO build `needs:` it.

- **`iso/tests/test-boot-config.sh`.** Runs `gnomarchy-boot update` against a
  fake tree: ESP, `/etc` and the snapshot directory are overridable through
  `GNOMARCHY_BOOT_ROOT`. It compares `limine.conf` with golden files in
  `iso/tests/fixtures/boot/` for:
  - a single kernel;
  - a kernel with fallback;
  - LUKS;
  - three snapshots;
  - `store` deduplication;
  - the 80% ESP budget;
  - a missing or malformed theme file;
  - `--default` escaping.

  It also checks that all 22 themes yield a complete palette.
- **The snapper plugin** with synthetic `create-snapshot-post` and
  `delete-snapshot-post` arguments: entry added, entry removed, store
  collected.
- **`iso/tests/test-installer-validate.sh`.**
  - Username and hostname rules against known good and bad values.
  - Every console keymap in `keymaps.tsv` exists under `/usr/share/kbd/keymaps`
    and maps keycode 16 to `q` on its plain layer.
  - Every X11 layout and variant exists in xkeyboard-config's `evdev.lst`.
- **shellcheck** over every new script. Verify the package name against the
  database before adding it to the container.

### CI answers

The answers file gains values that differ from every default, so a field
that is silently ignored fails a check:

```
GNOMARCHY_HOSTNAME=citest-host
GNOMARCHY_TIMEZONE=Europe/Berlin
GNOMARCHY_KEYMAP=de
```

### `verify-install.sh` (offline)

**Bootloader**
- `limine.conf` exists. Every `kernel_path` and `module_path` resolves to a
  file on the ESP whose b2sum matches its `#hash`.
- The root UUID in the command line equals the Btrfs UUID.
- `EFI/BOOT/BOOTX64.EFI` matches `/usr/share/limine/BOOTX64.EFI` by b2sum.
- `limine-bios.sys` is on the ESP, and the boot code in the disk's first
  440 bytes is non-zero (wipefs leaves none, so only `bios-install` writes
  it).
- The ESP is at least 4 GiB.
- The theme lines and `interface_branding` are present.

**initramfs, fstab**
- The mkinitcpio drop-in exists with `systemd`, `plymouth`, `sd-vconsole` and
  `gnomarchy-overlay`.
- `/etc/initcpio/install/gnomarchy-overlay` exists.
- fstab has no `subvolid=`.

**Snapshots**
- The snapper config exists and is listed in `/etc/conf.d/snapper`.
- The plugin is executable and both pacman hooks are present.
- snap-pac is installed.
- Snapshot 1 exists with its description, and it has a menu entry.

**Answers**
- `/etc/hostname`.
- `/etc/localtime`, tested with `-L` as CLAUDE.md requires.
- `KEYMAP` and the X11 layout.
- `/etc/gnomarchy/keyboard.conf`.

**Logs**
- The installer log is on the target.

### Second boot: GNOME session

- **Preparation.** The workflow's preparation step changes `/etc/kernel/cmdline`
  **as well as** `limine.conf`. Otherwise the first snapshot taken in the
  session regenerates the menu and drops the serial console. It also grants
  NOPASSWD for `snapper`, `pacman -U` and `gnomarchy-boot`.
- **Checks in `verify-session.sh`:**
  - `sudo snapper -c root create` goes through snapperd; the plugin adds the
    entry and its files match their hashes.
  - `pacman -U` of a package from the local cache (no network) leaves a
    snap-pac pre/post pair, and the post snapshot appears in the menu.
  - `gnomarchy-theme-set` to another theme changes `term_background` in
    `limine.conf` through the path unit.
  - GNOME input sources are `de` and `timedatectl` reports Europe/Berlin.
- **Before power-off.** The test runs `gnomarchy-boot update --default
  snapshot:N` for the snapshot made in this session. It uses that snapshot
  because snapshot 1 predates the CI autologin and autostart files.

### Third boot: from the snapshot

- **Checks.** `verify-session.sh` sees `gnomarchy.snapshot=N` on the command
  line and checks:
  - `/` is an overlay whose lower layer is `@snapshots/N/snapshot`;
  - writing to `/` succeeds and does not reach the snapshot;
  - the GNOME session came up;
  - the notifier ran (its journal tag).
- **Restore.** It then runs `gnomarchy snapshot restore N --yes` and powers
  off.
- **Restore check.** The workflow checks it on the host with
  `btrfs subvolume show`, without a fourth boot:
  - `@`'s parent UUID is snapshot N's UUID;
  - `@restore-backup-*` exists.
- **Report location.** Reports move from `/var/tmp`, which is volatile under a
  snapshot boot, to `~/.local/state/gnomarchy/verify/<boot>.txt` on the
  persistent `@home`.
- **Cost.** About 5–8 extra minutes.

### Encrypted install

A matrix entry with `GNOMARCHY_ENCRYPT=y` runs in parallel and skips the
boots:

- it installs;
- the host opens LUKS with the answers' password;
- it runs `verify-install.sh` with LUKS checks: `rd.luks.name=` matches the
  LUKS UUID, `sd-encrypt` is in HOOKS, there is no crypttab root entry, and
  `KEYMAP` and `FONT` are in `vconsole.conf`.

Typing a passphrase into QEMU from CI is too brittle to be worth it.

### Not covered

- A boot in BIOS mode. It is checked offline only: `limine-bios.sys` and the
  stage-1 signature.
- An encrypted boot.
- The gum screens; the unattended path bypasses them. Their validation and
  layout table are shared and unit-tested.

All three go in `TESTING.md`.

### Documentation, in the same commits as the behaviour

- **README:** Limine, snapshots in the menu (now true), the installer.
- **`manual/14-snapshots.md`:** rewritten — how snapshots are made, booting
  one, restoring, the ESP budget, no timeline.
- **`manual/02-getting-started.md`:** the installer screens.
- **`site/app.js`:** drop the "not in the menu" caveat.
- **`default/gnomarchy-skill/SKILL.md`**, the release notes in
  `build-and-release.yml`, and `TESTING.md`.
- **CLAUDE.md:**
  - a *Bootloader* section stating that `gnomarchy-boot` is the only writer of
    `limine.conf`;
  - the installer's new home;
  - the third boot and the report location;
  - the layout block.
- **`AGENTS.md`:** edited on this branch from its committed version. The
  user's uncommitted copy in the main checkout is not touched; merging the
  branch may conflict with it.

## Risks and open points

- **Remount of the snapshot root.** `systemd-remount-fs` acts on the root
  under a snapshot boot while fstab says `subvol=/@`. Dropping `subvolid=` is
  the known fix in grub-btrfs setups. The third CI boot is what proves it.
- **Fallback images.** Whether the `linux` preset still builds a fallback
  image decides whether the fallback entry ever appears. The generator handles
  both.
- **Plugin context.** snapper documents that it is unspecified whether the
  client or snapperd runs plugins. `gnomarchy-boot` only needs root and the
  mounted ESP, which both provide.
- **ESP layout.** An existing ESP smaller than 4 GiB only matters for
  reinstalls. The installer always repartitions.
