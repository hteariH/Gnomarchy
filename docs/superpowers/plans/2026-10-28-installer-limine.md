# Installer, Limine and Bootable Snapshots — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A gum text installer, Limine as the installed system's bootloader,
and snapper snapshots that are listed in, bootable from and restorable via the
Limine menu — official packages and our own bash only.

**Architecture:** `gnomarchy-boot` (root-owned, under
`/usr/local/lib/gnomarchy/boot`) is the only writer of `limine.conf`. It
regenerates the whole file from `/etc/kernel/cmdline`, the kernels on the ESP
and per-snapshot records on the ESP. A snapper plugin and two pacman hooks
call it. The installer moves out of `.automated_script.sh` into
`iso/installer/` and runs seven stages; CI gains a fast pre-ISO test job, an
encrypted-install matrix entry and a third QEMU boot from a snapshot.

**Tech Stack:** bash, gum, Limine 12 (extra), snapper + snap-pac (extra),
mkinitcpio with the systemd hooks, btrfs-progs, GitHub Actions, QEMU/OVMF.

**Spec:** `docs/superpowers/specs/2026-10-28-installer-limine-design.md`.
Read it first; Task 0 records where this plan refines it.

## Global Constraints

- `#!/bin/bash`, `[[ ]]` for strings, `(( ))` for arithmetic, `$HOME` never a hardcoded path.
- No `2>/dev/null` or `|| true` unless failure genuinely does not matter, and then say why in a comment.
- `install/gnomarchy-base.packages` stays official-repo only. Verify every new package name with `curl -sSL "https://archlinux.org/packages/search/json/?name=<pkg>"`.
- Anything touching dconf goes to `gnomarchy-first-run`, never into an install stage (no D-Bus in arch-chroot).
- No `X-GNOME-Autostart-Phase` in any autostart entry.
- New `bin/gnomarchy-*` commands get a case in `bin/gnomarchy`; `install/config/symlinks.sh` already links every `bin/gnomarchy*`.
- New executables: `git update-index --chmod=+x <file>` after `git add`.
- Root never executes scripts from a user's home at runtime: `gnomarchy-boot`, the snapper plugin and the pacman hooks run from root-owned copies.
- Files under `default/boot/lib/` that `gnomarchy-theme-set` sources (`palette.sh`) depend on nothing else.
- Limine menu text is ASCII: Limine's font is code page 437.
- Change README, the relevant `manual/` page and `CLAUDE.md` in the same commit as the behaviour they describe. `AGENTS.md` makes no claim about the installer, boot or snapshots, so it is not touched (the user has uncommitted work in it in the main checkout).
- Commit only files this plan names. Never stash, reset or switch branches in the shared checkout; work in the worktree `.claude/worktrees/installer-limine` on `feat/installer-limine`.

## Running the fast tests

The fast tests need an Arch userland (`b2sum`, `flock`, `loadkeys`,
`xkeyboard-config`, `shellcheck`, `systemctl`). Run them in a container from
the worktree root:

```bash
docker run --rm -v "$PWD:/w" -w /w archlinux:latest bash iso/tests/unit.sh --deps
```

A single test file: replace `iso/tests/unit.sh --deps` with
`bash -c 'pacman -Sy --noconfirm --needed kbd xkeyboard-config tzdata shellcheck >/dev/null && bash iso/tests/test-boot-config.sh'`.

If Docker Desktop is not running on this Windows host, ask the user to start
it; do not substitute Git Bash (it has no `flock` and no `loadkeys`). As a
last resort push the branch and read the `unit` job in CI.

## File map

| Path | Responsibility |
|---|---|
| `default/boot/gnomarchy-boot` | dispatcher: argument parsing, root check, locking |
| `default/boot/lib/common.sh` | paths (all under `GNOMARCHY_BOOT_ROOT`), logging, `boot_read_kv`, `boot_hash` |
| `default/boot/lib/palette.sh` | `alacritty.toml` → `boot-theme.conf` lines (also sourced by `gnomarchy-theme-set`) |
| `default/boot/lib/menu.sh` | kernels, command lines, `limine.conf` rendering and atomic write |
| `default/boot/lib/snapshots.sh` | snapshot records, content-addressed store, GC, ESP budget |
| `default/boot/lib/install.sh` | Limine onto ESP and disk, NVRAM entry |
| `default/boot/lib/snapper.sh` | root snapper config and snapshot 1, without D-Bus |
| `default/boot/lib/restore.sh` | make a snapshot the new `@` |
| `default/boot/50-gnomarchy-boot` | snapper plugin |
| `default/boot/95-gnomarchy-boot.hook`, `95-gnomarchy-limine.hook` | pacman hooks |
| `default/boot/gnomarchy-overlay` | mkinitcpio install hook for `systemd.volatile=overlay` |
| `default/boot/gnomarchy-boot-theme.{path,service}` | regenerate the menu when the theme file changes |
| `default/boot/snapshot-notify.desktop` | system autostart entry for the snapshot notice |
| `default/boot/deploy.sh` | root: install all of the above onto `/` (or `DESTDIR`) |
| `install/login/boot.sh` | install stage: run `deploy.sh` and `update` |
| `install/desktop/set-keyboard-layout.sh` | first-run: GNOME input sources from the installer's choice |
| `bin/gnomarchy-snapshot-restore`, `bin/gnomarchy-snapshot-notify` | user commands |
| `iso/installer/gnomarchy-install` | installer entry: answers, screens, stage runner |
| `iso/installer/lib/form.sh` | field rules, layout table access, unattended answers |
| `iso/installer/lib/keymaps.tsv` | curated keyboard layouts |
| `iso/installer/lib/disk.sh` | disk candidates and partition names |
| `iso/installer/lib/ui.sh` | gum screens and the progress view |
| `iso/installer/lib/stages.sh` | the seven stage functions |
| `iso/tests/lib/assert.sh` | assertions for the fast tests |
| `iso/tests/unit.sh` | runs every fast test and shellcheck |
| `iso/tests/test-palette.sh`, `test-boot-config.sh`, `test-deploy.sh`, `test-installer-validate.sh` | fast tests |
| `iso/tests/fixtures/boot/*.conf` | golden `limine.conf` files |

Modified: `iso/configs/airootfs/root/.automated_script.sh`,
`iso/builder/build-iso.sh`, `install/login/all.sh`, `install/login/plymouth.sh`,
`install/login/gdm.sh`, `bin/gnomarchy`, `bin/gnomarchy-theme-set`,
`bin/gnomarchy-update`, `bin/gnomarchy-first-run`,
`iso/tests/verify-install.sh`, `iso/tests/verify-session.sh`,
`.github/workflows/install-smoke-test.yml`, docs. Deleted:
`install/login/limine-snapper.sh`.

---

### Task 0: Record the plan's refinements in the spec

**Files:**
- Modify: `docs/superpowers/specs/2026-10-28-installer-limine-design.md`

These came out of reading the code while planning. The spec must say what is
built.

- [ ] **Step 1: Add a section after "Risks and open points"**

```markdown
## Refinements made while planning

- Snapshot titles use ASCII `|` separators, not `│`: Limine's font is code
  page 437.
- A snapshot's kernel is identified by matching the ESP's `vmlinuz-<kernel>`
  byte for byte (b2sum) against `usr/lib/modules/*/vmlinuz` inside the
  snapshot. No `file` parsing and no hash cache.
- snap-pac is already in `gnomarchy-base.packages`. What has to come last is
  the snapper config: without one snap-pac does nothing, so `install.sh`'s
  transactions leave no snapshots.
- The snapper config is written by `gnomarchy-boot snapper-init` from
  snapper's own template, not deployed from the repository.
- The keyboard layout is the first form field, and the live console switches
  to it, so passwords are typed in the layout they will be entered in.
- `default/boot/deploy.sh` (root) deploys the boot tooling. It runs only on
  machines with `/etc/gnomarchy/boot.conf`, i.e. installed from the ISO; on any
  other machine the bootloader is left alone.
- `/etc/gnomarchy/boot.conf` holds `DISK`, `ESP_PART`, `ENCRYPTED`.
- `pacstrap` adds `efibootmgr` and `plymouth`: the bootloader stage needs the
  first, and the initramfs HOOKS name the second before `install.sh` runs.
- `95-gnomarchy-boot.hook` fires after every transaction (`Target = *`)
  rather than mirroring mkinitcpio's trigger list; an update costs two hashes.
- A snapshot whose command line cannot be derived is left out of the menu, so
  the menu stays bootable; `snapshot-add` refuses it.
- `gnomarchy-boot restore N` takes no `--yes`; confirmation is the user
  command's job (`gnomarchy snapshot restore N --yes` skips it).
- An unattended failure powers the machine off, so CI fails fast instead of
  waiting out its timeout.
- GDM's encrypted-install autologin keys on `ENCRYPTED=1` in `boot.conf`;
  there is no crypttab to detect any more.
- `AGENTS.md` makes no claim about the installer, boot or snapshots and is not
  changed.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-10-28-installer-limine-design.md
git commit -m "docs(spec): record refinements made while planning"
```

---

### Task 1: Test harness and the theme palette

**Files:**
- Create: `iso/tests/lib/assert.sh`, `iso/tests/unit.sh`, `iso/tests/test-palette.sh`, `default/boot/lib/palette.sh`

**Interfaces:**
- Produces: `t_ok`, `t_no`, `t_eq LABEL ACTUAL EXPECTED`, `t_true LABEL CMD...`, `t_false LABEL CMD...`, `t_golden LABEL ACTUAL_FILE GOLDEN_FILE`, `t_done`.
- Produces: `boot_palette_from_alacritty FILE` → prints `BACKGROUND=`, `FOREGROUND=`, `ACCENT=`, `NORMAL_0..7=`, `BRIGHT_0..7=` (19 lines, lowercase `rrggbb`), returns 1 naming the first missing colour.

- [ ] **Step 1: Write `iso/tests/lib/assert.sh`**

```bash
#!/bin/bash
# Assertions for the fast tests. A test script sources this, makes its checks
# and ends with t_done, whose status becomes the script's.

t_pass=0
t_fail=0

t_ok() {
  printf '  PASS  %s\n' "$1"
  t_pass=$((t_pass + 1))
}

t_no() {
  printf '  FAIL  %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" | sed 's/^/        /'
  fi
  t_fail=$((t_fail + 1))
}

# t_eq LABEL ACTUAL EXPECTED
t_eq() {
  if [[ "$2" == "$3" ]]; then
    t_ok "$1"
  else
    t_no "$1" "expected: $3"$'\n'"actual:   $2"
  fi
}

# t_true LABEL COMMAND... passes when the command succeeds.
t_true() {
  local label="$1"
  shift
  if "$@"; then t_ok "$label"; else t_no "$label" "command failed: $*"; fi
}

# t_false LABEL COMMAND... passes when the command fails.
t_false() {
  local label="$1"
  shift
  if "$@"; then t_no "$label" "command unexpectedly succeeded: $*"; else t_ok "$label"; fi
}

# t_golden LABEL ACTUAL_FILE GOLDEN_FILE
# GNOMARCHY_UPDATE_GOLDEN=1 rewrites the golden file instead of comparing; read
# the diff before committing one.
t_golden() {
  local label="$1" actual="$2" golden="$3"
  if [[ "${GNOMARCHY_UPDATE_GOLDEN:-}" == 1 ]]; then
    cp "$actual" "$golden"
    t_ok "$label (golden updated)"
  elif diff -u "$golden" "$actual" >/dev/null; then
    t_ok "$label"
  else
    t_no "$label" "$(diff -u "$golden" "$actual")"
  fi
}

t_done() {
  printf '\n  %d passed, %d failed\n' "$t_pass" "$t_fail"
  ((t_fail == 0))
}
```

- [ ] **Step 2: Write `iso/tests/unit.sh`**

```bash
#!/bin/bash
# Runs every fast test and shellcheck. Needs an Arch userland; CI runs it in
# archlinux:latest, and so can you, from the repository root:
#
#   docker run --rm -v "$PWD:/w" -w /w archlinux:latest bash iso/tests/unit.sh --deps
set -uo pipefail
cd "$(dirname "$0")/../.."

if [[ "${1:-}" == --deps ]]; then
  pacman -Sy --noconfirm --needed kbd xkeyboard-config tzdata shellcheck diffutils >/dev/null || exit 1
fi

rc=0
for t in iso/tests/test-*.sh; do
  echo "=== $t"
  bash "$t" || rc=1
done

echo "=== shellcheck"
# Entry points only: -x follows their `source` lines and checks each library
# in the context that defines its variables. Checked alone, a library reports
# every path from common.sh as unassigned.
mapfile -t scripts < <(
  printf '%s\n' \
    default/boot/gnomarchy-boot default/boot/50-gnomarchy-boot default/boot/deploy.sh \
    iso/installer/gnomarchy-install \
    bin/gnomarchy-snapshot-restore bin/gnomarchy-snapshot-notify \
    install/login/boot.sh install/desktop/set-keyboard-layout.sh \
    iso/tests/test-*.sh |
    while read -r f; do [[ -f "$f" ]] && printf '%s\n' "$f"; done
)
shellcheck -x -S warning "${scripts[@]}" || rc=1

exit "$rc"
```

The `[[ -f ]]` filter lets the runner work while later tasks have not yet
created their files.

- [ ] **Step 3: Write the failing test `iso/tests/test-palette.sh`**

```bash
#!/bin/bash
# Every bundled theme must yield a complete Limine palette.
set -u
cd "$(dirname "$0")/../.."
# shellcheck source=iso/tests/lib/assert.sh
source iso/tests/lib/assert.sh
# shellcheck source=default/boot/lib/palette.sh
source default/boot/lib/palette.sh

out="$(boot_palette_from_alacritty themes/tokyo-night/alacritty.toml)"
t_eq "tokyo-night background" "$(sed -n 's/^BACKGROUND=//p' <<<"$out")" "1a1b26"
t_eq "tokyo-night foreground" "$(sed -n 's/^FOREGROUND=//p' <<<"$out")" "c0caf5"
t_eq "the accent is the normal blue" "$(sed -n 's/^ACCENT=//p' <<<"$out")" "7aa2f7"
t_eq "normal black is NORMAL_0" "$(sed -n 's/^NORMAL_0=//p' <<<"$out")" "15161e"
t_eq "bright white is BRIGHT_7" "$(sed -n 's/^BRIGHT_7=//p' <<<"$out")" "c0caf5"

for theme in themes/*/; do
  name="$(basename "$theme")"
  if out="$(boot_palette_from_alacritty "${theme}alacritty.toml" 2>&1)" &&
    [[ "$(grep -cE '^[A-Z0-9_]+=[0-9a-f]{6}$' <<<"$out")" == 19 ]]; then
    t_ok "$name yields 19 palette values"
  else
    t_no "$name does not yield a full palette" "$out"
  fi
done

tmp="$(mktemp)"
printf '[colors.primary]\nbackground = "#000000"\n' >"$tmp"
t_false "a palette with missing colours is rejected" boot_palette_from_alacritty "$tmp"
rm -f "$tmp"

t_done
```

- [ ] **Step 4: Run it to see it fail**

Run (container, see *Running the fast tests*): `bash iso/tests/test-palette.sh`
Expected: `default/boot/lib/palette.sh: No such file or directory`, then FAILs.

- [ ] **Step 5: Write `default/boot/lib/palette.sh`**

```bash
#!/bin/bash
# Theme palette for the Limine menu.
#
# A theme's alacritty.toml is the canonical palette (CLAUDE.md, The theme
# engine). This turns it into the KEY=rrggbb lines of
# /etc/gnomarchy/boot-theme.conf, which gnomarchy-boot reads. Sourced by
# gnomarchy-theme-set as the user, so it depends on nothing else here.

# boot_palette_from_alacritty FILE — prints BACKGROUND, FOREGROUND, ACCENT,
# NORMAL_0..7 and BRIGHT_0..7, or fails naming the first missing colour.
boot_palette_from_alacritty() {
  local file="$1" section="" line key i
  local re_colour='^[[:space:]]*([a-z]+)[[:space:]]*=[[:space:]]*"#?([0-9a-fA-F]{6})"'
  local names=(black red green yellow blue magenta cyan white)
  local -A colour=()

  if [[ ! -f "$file" ]]; then
    printf 'palette: no such file: %s\n' "$file" >&2
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ "$line" =~ ^\[colors\.(primary|normal|bright)\] ]]; then
      section="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\[ ]]; then
      section=""
    elif [[ -n "$section" && "$line" =~ $re_colour ]]; then
      colour["$section.${BASH_REMATCH[1]}"]="${BASH_REMATCH[2],,}"
    fi
  done <"$file"

  for key in primary.background primary.foreground; do
    if [[ -z "${colour[$key]:-}" ]]; then
      printf 'palette: %s has no %s\n' "$file" "$key" >&2
      return 1
    fi
  done
  for i in "${!names[@]}"; do
    for key in "normal.${names[i]}" "bright.${names[i]}"; do
      if [[ -z "${colour[$key]:-}" ]]; then
        printf 'palette: %s has no %s\n' "$file" "$key" >&2
        return 1
      fi
    done
  done

  printf 'BACKGROUND=%s\n' "${colour[primary.background]}"
  printf 'FOREGROUND=%s\n' "${colour[primary.foreground]}"
  printf 'ACCENT=%s\n' "${colour[normal.blue]}"
  for i in "${!names[@]}"; do
    printf 'NORMAL_%d=%s\n' "$i" "${colour[normal.${names[i]}]}"
  done
  for i in "${!names[@]}"; do
    printf 'BRIGHT_%d=%s\n' "$i" "${colour[bright.${names[i]}]}"
  done
}
```

- [ ] **Step 6: Run the test to see it pass**

Run: `bash iso/tests/test-palette.sh`
Expected: 5 + 22 + 1 PASS lines, `28 passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add iso/tests/lib/assert.sh iso/tests/unit.sh iso/tests/test-palette.sh default/boot/lib/palette.sh
git commit -m "test(boot): fast-test harness and the Limine theme palette"
```

---

### Task 2: `gnomarchy-boot update` — the menu generator

**Files:**
- Create: `default/boot/gnomarchy-boot`, `default/boot/lib/common.sh`, `default/boot/lib/menu.sh`, `iso/tests/test-boot-config.sh`, `iso/tests/fixtures/boot/single.conf`

**Interfaces:**
- Consumes: `boot_palette_from_alacritty` (tests only).
- Produces (later tasks rely on these exact names):
  - common.sh: `BOOT_ROOT BOOT_ESP BOOT_STATE BOOT_STORE BOOT_ENTRIES BOOT_CONF BOOT_THEME BOOT_CMDLINE BOOT_SNAPSHOTS BOOT_LIMINE_SHARE`, `boot_log MSG`, `boot_die MSG`, `boot_read_kv FILE ARRAY_NAME` (returns 1 if the file is missing), `boot_hash FILE`.
  - menu.sh: `boot_kernels`, `boot_default_kernel`, `boot_snapshot_numbers` (newest first), `boot_base_cmdline`, `boot_snapshot_cmdline BASE N`, `boot_snapshot_title N DATE DESC`, `boot_escape_entry TEXT`, `boot_theme_lines`, `boot_render [ID]`, `boot_write_conf [ID]`.
  - Entry record `$BOOT_ENTRIES/<N>.conf`: `KERNEL= VERSION= KERNEL_HASH= INITRAMFS_HASH= DATE= DESCRIPTION=` (written in Task 3, read here).

- [ ] **Step 1: Write the failing test `iso/tests/test-boot-config.sh`**

This file grows in Tasks 3 and 4; start it with the tree helpers and the
first cases.

```bash
#!/bin/bash
# gnomarchy-boot against a throwaway tree: limine.conf generation, snapshot
# entries, the ESP budget, Limine installation, snapper setup and the plugin.
set -u
cd "$(dirname "$0")/../.."
REPO="$PWD"
# shellcheck source=iso/tests/lib/assert.sh
source iso/tests/lib/assert.sh
# shellcheck source=default/boot/lib/palette.sh
source default/boot/lib/palette.sh

BOOT="$REPO/default/boot/gnomarchy-boot"
FIXTURES="$REPO/iso/tests/fixtures/boot"
export TZ=UTC
KVERS=(6.17.5-arch1-1 6.17.6-arch1-1 6.17.7-arch1-1)
PAD_KB=0

# Fixture contents are a function of the kernel version, so normalize() can
# turn any hash back into a readable name.
kernel_bytes() {
  printf 'kernel %s\n' "$1"
  if ((PAD_KB)); then head -c $((PAD_KB * 1024)) /dev/zero; fi
}
initramfs_bytes() {
  printf 'initramfs for %s\n' "$1"
  if ((PAD_KB)); then head -c $((PAD_KB * 1024)) /dev/zero; fi
}
fallback_bytes() { printf 'fallback initramfs for %s\n' "$1"; }

# set_esp_kernel VERSION — the ESP's linux kernel and initramfs become VERSION.
set_esp_kernel() {
  kernel_bytes "$1" >"$T/boot/vmlinuz-linux"
  initramfs_bytes "$1" >"$T/boot/initramfs-linux.img"
}

new_tree() {
  T="$(mktemp -d)"
  export GNOMARCHY_BOOT_ROOT="$T"
  mkdir -p "$T/boot" "$T/etc/kernel" "$T/etc/gnomarchy" "$T/.snapshots"
  set_esp_kernel "${KVERS[0]}"
  echo 'root=UUID=1111-2222 rw rootflags=subvol=@ quiet splash' >"$T/etc/kernel/cmdline"
  boot_palette_from_alacritty "$REPO/themes/tokyo-night/alacritty.toml" >"$T/etc/gnomarchy/boot-theme.conf"
}

# add_snapshot N DATE DESCRIPTION [KERNEL_VERSION] — a snapper snapshot as
# snapper leaves it: info.xml plus the subvolume with its kernel modules.
add_snapshot() {
  local n="$1" ver="${4:-${KVERS[0]}}"
  mkdir -p "$T/.snapshots/$n/snapshot/usr/lib/modules/$ver"
  kernel_bytes "$ver" >"$T/.snapshots/$n/snapshot/usr/lib/modules/$ver/vmlinuz"
  cat >"$T/.snapshots/$n/info.xml" <<EOF
<?xml version="1.0"?>
<snapshot>
  <type>single</type>
  <num>$n</num>
  <date>$2</date>
  <description>$3</description>
</snapshot>
EOF
}

# normalize FILE — every fixture hash replaced by <vmlinuz VER> and friends.
normalize() {
  local out ver h
  out="$(<"$1")"
  for ver in "${KVERS[@]}"; do
    h="$(kernel_bytes "$ver" | b2sum | cut -d' ' -f1)"
    out="${out//$h/<vmlinuz $ver>}"
    h="$(initramfs_bytes "$ver" | b2sum | cut -d' ' -f1)"
    out="${out//$h/<initramfs $ver>}"
    h="$(fallback_bytes "$ver" | b2sum | cut -d' ' -f1)"
    out="${out//$h/<fallback $ver>}"
  done
  printf '%s\n' "$out"
}

golden() { # LABEL NAME
  normalize "$T/boot/limine.conf" >"$T/normalized.conf"
  t_golden "$1" "$T/normalized.conf" "$FIXTURES/$2"
}

conf_has() { grep -qxF -- "$1" "$T/boot/limine.conf"; }

echo "--- one kernel"
new_tree
t_true "update succeeds" "$BOOT" update
golden "single kernel menu" single.conf

echo "--- fallback image and a second kernel"
fallback_bytes "${KVERS[0]}" >"$T/boot/initramfs-linux-fallback.img"
printf 'lts kernel\n' >"$T/boot/vmlinuz-linux-lts"
printf 'lts initramfs\n' >"$T/boot/initramfs-linux-lts.img"
"$BOOT" update
t_true "fallback entry present" conf_has "//linux (fallback)"
t_true "fallback entry uses the fallback image" grep -q "module_path: boot():/initramfs-linux-fallback.img#" "$T/boot/limine.conf"
t_true "linux-lts gets its own entry" conf_has "//linux-lts"
t_true "the default stays linux" conf_has "default_entry: Gnomarchy/linux"
t_eq "linux is listed before linux-lts" "$(grep -E '^//linux(-lts)?$' "$T/boot/limine.conf" | tr '\n' ' ')" "//linux //linux-lts "

echo "--- a kernel without an initramfs is skipped"
printf 'orphan\n' >"$T/boot/vmlinuz-linux-zen"
"$BOOT" update 2>"$T/log"
t_false "no entry for linux-zen" conf_has "//linux-zen"
t_true "the skip is reported" grep -q "skipping linux-zen" "$T/log"

echo "--- theme file missing or malformed"
new_tree
rm "$T/etc/gnomarchy/boot-theme.conf"
"$BOOT" update 2>"$T/log"
t_false "no palette without a theme file" grep -q '^term_palette:' "$T/boot/limine.conf"
t_true "branding is still written" conf_has "interface_branding: Gnomarchy"
t_true "the missing theme is reported" grep -q "boot-theme.conf" "$T/log"
printf 'BACKGROUND=$(reboot)\n' >"$T/etc/gnomarchy/boot-theme.conf"
"$BOOT" update 2>"$T/log"
t_false "a malformed theme writes no palette" grep -q '^term_' "$T/boot/limine.conf"

echo "--- no kernel at all"
new_tree
"$BOOT" update
cp "$T/boot/limine.conf" "$T/before.conf"
rm "$T/boot/vmlinuz-linux"
t_false "update fails without a kernel" "$BOOT" update
t_true "limine.conf is left as it was" cmp -s "$T/before.conf" "$T/boot/limine.conf"
t_false "no temporary file is left behind" test -e "$T/boot/limine.conf.new"

t_done
```

- [ ] **Step 2: Write the golden file `iso/tests/fixtures/boot/single.conf`**

```text
# Generated by gnomarchy-boot; rewritten on every kernel update, snapshot and
# theme change. Edit /etc/kernel/cmdline, not this file.
timeout: 3
default_entry: Gnomarchy/linux
interface_branding: Gnomarchy
interface_branding_colour: 7aa2f7
term_palette: 15161e;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;a9b1d6
term_palette_bright: 414868;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;c0caf5
term_background: 001a1b26
term_foreground: c0caf5

/+Gnomarchy
//linux
    protocol: linux
    kernel_path: boot():/vmlinuz-linux#<vmlinuz 6.17.5-arch1-1>
    module_path: boot():/initramfs-linux.img#<initramfs 6.17.5-arch1-1>
    kernel_cmdline: root=UUID=1111-2222 rw rootflags=subvol=@ quiet splash
```

- [ ] **Step 3: Run it to see it fail**

Run: `bash iso/tests/test-boot-config.sh`
Expected: FAIL on "update succeeds" (`gnomarchy-boot: No such file or directory`).

- [ ] **Step 4: Write `default/boot/lib/common.sh`**

```bash
#!/bin/bash
# Paths and helpers shared by gnomarchy-boot and its libraries.
#
# Every path is rooted at GNOMARCHY_BOOT_ROOT, empty on a real system, so the
# fast tests run this exact code against a throwaway tree.

BOOT_ROOT="${GNOMARCHY_BOOT_ROOT:-}"
BOOT_ESP="$BOOT_ROOT/boot"
BOOT_STATE="$BOOT_ESP/gnomarchy"
BOOT_STORE="$BOOT_STATE/store"
BOOT_ENTRIES="$BOOT_STATE/entries"
BOOT_CONF="$BOOT_ROOT/etc/gnomarchy/boot.conf"
BOOT_THEME="$BOOT_ROOT/etc/gnomarchy/boot-theme.conf"
BOOT_CMDLINE="$BOOT_ROOT/etc/kernel/cmdline"
BOOT_SNAPSHOTS="$BOOT_ROOT/.snapshots"
BOOT_LIMINE_SHARE="$BOOT_ROOT/usr/share/limine"

boot_log() { printf 'gnomarchy-boot: %s\n' "$*" >&2; }

boot_die() {
  boot_log "error: $*"
  exit 1
}

# boot_read_kv FILE ARRAY — loads KEY=VALUE lines into an associative array.
# Never sources the file: snapshot descriptions and the theme file hold text a
# user chose.
boot_read_kv() {
  local file="$1" line
  local -n _boot_kv="$2"
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
      _boot_kv["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  done <"$file"
  return 0
}

boot_hash() {
  local sum
  sum="$(b2sum "$1")" || return 1
  printf '%s\n' "${sum%% *}"
}
```

- [ ] **Step 5: Write `default/boot/lib/menu.sh`**

```bash
#!/bin/bash
# limine.conf generation. The render functions print; boot_write_conf puts the
# result on the ESP.

# Kernel names with both an image and an initramfs on the ESP, sorted.
boot_kernels() {
  local img name
  for img in "$BOOT_ESP"/vmlinuz-*; do
    [[ -f "$img" ]] || continue
    name="${img##*/vmlinuz-}"
    if [[ -f "$BOOT_ESP/initramfs-$name.img" ]]; then
      printf '%s\n' "$name"
    else
      boot_log "skipping $name: no initramfs-$name.img on the ESP"
    fi
  done | sort
}

# The kernel snapshots are recorded against: linux if installed, else the first.
boot_default_kernel() {
  local kernels
  kernels="$(boot_kernels)"
  if [[ -z "$kernels" ]]; then
    boot_log "no kernel with an initramfs in $BOOT_ESP"
    return 1
  fi
  if grep -qx linux <<<"$kernels"; then
    printf 'linux\n'
  else
    printf '%s\n' "${kernels%%$'\n'*}"
  fi
}

# Snapshot numbers that have a menu record, newest first.
boot_snapshot_numbers() {
  local f n
  for f in "$BOOT_ENTRIES"/*.conf; do
    [[ -f "$f" ]] || continue
    n="${f##*/}"
    n="${n%.conf}"
    if [[ "$n" =~ ^[0-9]+$ ]]; then printf '%s\n' "$n"; fi
  done | sort -rn
}

# /etc/kernel/cmdline with whitespace collapsed to single spaces.
boot_base_cmdline() {
  local -a words
  if [[ ! -f "$BOOT_CMDLINE" ]]; then
    boot_log "no $BOOT_CMDLINE"
    return 1
  fi
  read -ra words < <(tr -s '[:space:]' ' ' <"$BOOT_CMDLINE")
  if ((${#words[@]} == 0)); then
    boot_log "$BOOT_CMDLINE is empty"
    return 1
  fi
  printf '%s\n' "${words[*]}"
}

# boot_snapshot_cmdline BASE N — the base command line pointed at snapshot N,
# read-only under a tmpfs overlay.
boot_snapshot_cmdline() {
  local word found=0
  local -a words out=()
  read -ra words <<<"$1"
  for word in "${words[@]}"; do
    case "$word" in
      rw) out+=(ro) ;;
      rootflags=subvol=@ | rootflags=subvol=/@)
        out+=("rootflags=subvol=@snapshots/$2/snapshot")
        found=1
        ;;
      splash) ;;
      *) out+=("$word") ;;
    esac
  done
  if ((!found)); then
    boot_log "the base command line has no rootflags=subvol=@; cannot point it at snapshot $2"
    return 1
  fi
  out+=(systemd.volatile=overlay "gnomarchy.snapshot=$2")
  printf '%s\n' "${out[*]}"
}

# boot_snapshot_title N DATE DESCRIPTION
boot_snapshot_title() {
  if [[ -n "$3" ]]; then
    printf '%s | %s | %s' "$1" "$2" "$3"
  else
    printf '%s | %s' "$1" "$2"
  fi
}

# Limine entry paths separate levels with /; a title's own /, \ and # are
# escaped as Limine's default_entry documentation requires.
boot_escape_entry() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\//\\/}"
  s="${s//\#/\\#}"
  printf '%s' "$s"
}

# Colour lines from /etc/gnomarchy/boot-theme.conf. That file is writable by
# wheel, so every value must be plain hex or none of them is used.
boot_theme_lines() {
  local key i
  local -A t=()
  local -a normal=() bright=()
  if ! boot_read_kv "$BOOT_THEME" t; then
    boot_log "no $BOOT_THEME; the menu keeps Limine's own colours"
    return 0
  fi
  for key in BACKGROUND FOREGROUND ACCENT NORMAL_{0..7} BRIGHT_{0..7}; do
    if [[ ! "${t[$key]:-}" =~ ^[0-9a-fA-F]{6}$ ]]; then
      boot_log "$BOOT_THEME: $key is missing or not rrggbb; the menu keeps Limine's own colours"
      return 0
    fi
  done
  for i in {0..7}; do
    normal+=("${t[NORMAL_$i]}")
    bright+=("${t[BRIGHT_$i]}")
  done
  local IFS=';'
  printf 'interface_branding_colour: %s\n' "${t[ACCENT]}"
  printf 'term_palette: %s\n' "${normal[*]}"
  printf 'term_palette_bright: %s\n' "${bright[*]}"
  printf 'term_background: 00%s\n' "${t[BACKGROUND]}"
  printf 'term_foreground: %s\n' "${t[FOREGROUND]}"
}

# boot_render_entry TITLE KERNEL_PATH KERNEL_HASH MODULE_PATH MODULE_HASH CMDLINE
boot_render_entry() {
  printf '%s\n' \
    "$1" \
    "    protocol: linux" \
    "    kernel_path: boot():$2#$3" \
    "    module_path: boot():$4#$5" \
    "    kernel_cmdline: $6"
}

# boot_render_kernel TITLE KERNEL INITRAMFS_FILE CMDLINE — hashes ESP files.
boot_render_kernel() {
  local kh mh
  kh="$(boot_hash "$BOOT_ESP/vmlinuz-$2")" || return 1
  mh="$(boot_hash "$BOOT_ESP/$3")" || return 1
  boot_render_entry "$1" "/vmlinuz-$2" "$kh" "/$3" "$mh" "$4"
}

# boot_render [ID] — prints limine.conf. ID is snapshot:N or a kernel name;
# without one the default is the linux kernel.
boot_render() {
  local id="${1:-}" base kernel n title cmdline default_path
  local -a kernels snapshots
  base="$(boot_base_cmdline)" || return 1
  mapfile -t kernels < <(boot_kernels)
  if ((${#kernels[@]} == 0)); then
    boot_log "no kernel with an initramfs in $BOOT_ESP"
    return 1
  fi
  mapfile -t snapshots < <(boot_snapshot_numbers)

  case "$id" in
    "")
      default_path="Gnomarchy/$(boot_default_kernel)" || return 1
      ;;
    snapshot:*)
      n="${id#snapshot:}"
      local -A d=()
      if ! boot_read_kv "$BOOT_ENTRIES/$n.conf" d; then
        boot_log "snapshot $n has no menu entry"
        return 1
      fi
      title="$(boot_snapshot_title "$n" "${d[DATE]:-}" "${d[DESCRIPTION]:-}")"
      default_path="Gnomarchy/Snapshots/$(boot_escape_entry "$title")"
      ;;
    *)
      if ! printf '%s\n' "${kernels[@]}" | grep -qxF -- "$id"; then
        boot_log "no kernel named $id"
        return 1
      fi
      default_path="Gnomarchy/$(boot_escape_entry "$id")"
      ;;
  esac

  printf '%s\n' \
    "# Generated by gnomarchy-boot; rewritten on every kernel update, snapshot and" \
    "# theme change. Edit /etc/kernel/cmdline, not this file." \
    "timeout: 3" \
    "default_entry: $default_path" \
    "interface_branding: Gnomarchy"
  boot_theme_lines
  printf '\n/+Gnomarchy\n'

  for kernel in "${kernels[@]}"; do
    boot_render_kernel "//$kernel" "$kernel" "initramfs-$kernel.img" "$base" || return 1
    if [[ -f "$BOOT_ESP/initramfs-$kernel-fallback.img" ]]; then
      boot_render_kernel "//$kernel (fallback)" "$kernel" "initramfs-$kernel-fallback.img" "$base" || return 1
    fi
  done

  ((${#snapshots[@]})) || return 0
  printf '//Snapshots\n'
  for n in "${snapshots[@]}"; do
    local -A e=()
    boot_read_kv "$BOOT_ENTRIES/$n.conf" e
    # A broken record must not take the whole menu with it.
    if [[ ! -f "$BOOT_STORE/${e[KERNEL_HASH]:-none}" || ! -f "$BOOT_STORE/${e[INITRAMFS_HASH]:-none}" ]]; then
      boot_log "snapshot $n: its boot files are missing from the store; left out of the menu"
      continue
    fi
    if ! cmdline="$(boot_snapshot_cmdline "$base" "$n")"; then
      boot_log "snapshot $n left out of the menu"
      continue
    fi
    title="$(boot_snapshot_title "$n" "${e[DATE]:-}" "${e[DESCRIPTION]:-}")"
    boot_render_entry "///$title" \
      "/gnomarchy/store/${e[KERNEL_HASH]}" "${e[KERNEL_HASH]}" \
      "/gnomarchy/store/${e[INITRAMFS_HASH]}" "${e[INITRAMFS_HASH]}" \
      "$cmdline"
  done
}

# boot_write_conf [ID] — renders to a temporary file and renames it over
# limine.conf, so a failure never leaves a half-written menu.
boot_write_conf() {
  local tmp="$BOOT_ESP/limine.conf.new"
  if ! boot_render "${1:-}" >"$tmp"; then
    rm -f "$tmp"
    boot_log "limine.conf left unchanged"
    return 1
  fi
  sync "$tmp"
  mv -f "$tmp" "$BOOT_ESP/limine.conf"
}
```

Note `default_path="Gnomarchy/$(boot_default_kernel)" || return 1` — the
assignment's status is the substitution's, so a failure is caught.

- [ ] **Step 6: Write `default/boot/gnomarchy-boot`**

```bash
#!/bin/bash
# gnomarchy-boot — the only program that writes limine.conf.
#
# Runs as root from /usr/local/lib/gnomarchy/boot (root never executes scripts
# from a user's home). Called by the installer, the pacman hooks, the snapper
# plugin, the theme path unit and `gnomarchy snapshot restore`.
# Design: docs/superpowers/specs/2026-10-28-installer-limine-design.md
# shellcheck source-path=SCRIPTDIR
set -Eeuo pipefail

BOOT_LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib"
# shellcheck source=lib/common.sh
source "$BOOT_LIB/common.sh"
# shellcheck source=lib/menu.sh
source "$BOOT_LIB/menu.sh"
for lib in snapshots install snapper restore; do
  # Later tasks add these; until then their subcommands are unavailable.
  # shellcheck source=/dev/null
  [[ -f "$BOOT_LIB/$lib.sh" ]] && source "$BOOT_LIB/$lib.sh"
done

usage() {
  cat <<'EOF'
Usage: gnomarchy-boot <command>

  install                 put Limine on the ESP and the disk (UEFI and BIOS)
  update [--default ID]   regenerate limine.conf; ID is snapshot:N or a kernel
  snapshot-add N          give snapper snapshot N a menu entry
  snapshot-remove N       drop snapshot N's menu entry
  snapper-init            create the root snapper config and snapshot 1
  restore N               make snapshot N the root filesystem from next boot
EOF
}

if [[ $EUID -ne 0 && -z "$BOOT_ROOT" ]]; then
  boot_die "must run as root"
fi

# One writer at a time: a pacman hook, the snapper plugin and a theme change
# can all fire at once.
boot_lock() {
  mkdir -p "$BOOT_STATE"
  exec 9>"$BOOT_STATE/lock"
  flock 9
}

cmd="${1:-}"
(($#)) && shift

case "$cmd" in
  update)
    default=""
    if [[ "${1:-}" == --default ]]; then
      default="${2:?--default needs snapshot:N or a kernel name}"
    fi
    boot_lock
    boot_write_conf "$default"
    ;;
  snapshot-add)
    boot_lock
    boot_snapshot_add "${1:?snapshot-add needs a snapshot number}"
    boot_write_conf
    ;;
  snapshot-remove)
    boot_lock
    boot_snapshot_remove "${1:?snapshot-remove needs a snapshot number}"
    boot_write_conf
    ;;
  install)
    boot_lock
    boot_install
    ;;
  snapper-init)
    # No lock: creating snapshot 1 calls back into snapshot-add, which takes it.
    boot_snapper_init
    ;;
  restore)
    boot_lock
    boot_restore "${1:?restore needs a snapshot number}"
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
```

The `[[ -f ]] && source` loop is temporary; Task 4 Step 6 replaces it with
plain `source` lines once all libraries exist.

Run `chmod +x default/boot/gnomarchy-boot` now: the tests execute it directly.

- [ ] **Step 7: Run the test to see it pass**

Run: `bash iso/tests/test-boot-config.sh`
Expected: all PASS. If the golden diff shows only whitespace, fix the code, not
the golden file.

- [ ] **Step 8: Mark the executable and commit**

```bash
git add default/boot/gnomarchy-boot default/boot/lib/common.sh default/boot/lib/menu.sh \
  iso/tests/test-boot-config.sh iso/tests/fixtures/boot/single.conf
git update-index --chmod=+x default/boot/gnomarchy-boot
git commit -m "feat(boot): gnomarchy-boot generates limine.conf"
```

---

### Task 3: Snapshot entries, the store, the ESP budget and the snapper plugin

**Files:**
- Create: `default/boot/lib/snapshots.sh`, `default/boot/50-gnomarchy-boot`, `iso/tests/fixtures/boot/snapshots.conf`
- Modify: `iso/tests/test-boot-config.sh` (insert cases before `t_done`)

**Interfaces:**
- Consumes: everything from Task 2.
- Produces: `boot_snapshot_kernel_version N KERNEL` (prints the module version, fails if none matches), `boot_snapshot_add N`, `boot_snapshot_remove N`, `boot_store_gc`, `boot_enforce_budget`, `boot_esp_usage`.
- Test-only env: `GNOMARCHY_BOOT_ESP_SIZE_KB` (ESP size; usage measured with `du --apparent-size`), `GNOMARCHY_BOOT_BIN` (plugin target).

- [ ] **Step 1: Add the failing cases to `iso/tests/test-boot-config.sh`** (before the final `t_done`)

```bash
echo "--- snapshots across a kernel upgrade"
new_tree
add_snapshot 2 "2026-10-27 09:15:00" "before upgrade"
t_true "snapshot 2 is added" "$BOOT" snapshot-add 2
set_esp_kernel "${KVERS[1]}"
add_snapshot 3 "2026-10-28 14:02:11" "pacman -Syu" "${KVERS[1]}"
"$BOOT" snapshot-add 3
add_snapshot 4 "2026-10-28 18:30:45" "manual" "${KVERS[1]}"
"$BOOT" snapshot-add 4
golden "snapshot menu, newest first" snapshots.conf
t_eq "two kernels, two initramfs images: four store files" "$(find "$T/boot/gnomarchy/store" -type f | wc -l)" "4"
t_true "the record names the module version" grep -qx "VERSION=${KVERS[1]}" "$T/boot/gnomarchy/entries/3.conf"

echo "--- descriptions are data"
add_snapshot 6 "2026-10-28 20:00:00" 'pacman -S a/b #1 &amp; $(reboot)' "${KVERS[1]}"
"$BOOT" snapshot-add 6
t_true "XML entities are decoded, shell text is kept literally" \
  grep -qxF 'DESCRIPTION=pacman -S a/b #1 & $(reboot)' "$T/boot/gnomarchy/entries/6.conf"
t_true "--default snapshot:6 succeeds" "$BOOT" update --default snapshot:6
t_true "the default entry path is escaped" \
  conf_has 'default_entry: Gnomarchy/Snapshots/6 | 2026-10-28 20:00 | pacman -S a\/b \#1 & $(reboot)'
cp "$T/boot/limine.conf" "$T/before.conf"
t_false "--default for a snapshot without an entry fails" "$BOOT" update --default snapshot:99
t_true "and leaves limine.conf alone" cmp -s "$T/before.conf" "$T/boot/limine.conf"
"$BOOT" update
t_true "a plain update returns the default to linux" conf_has "default_entry: Gnomarchy/linux"

echo "--- removing a snapshot"
t_true "snapshot-remove 2 succeeds" "$BOOT" snapshot-remove 2
t_false "its record is gone" test -e "$T/boot/gnomarchy/entries/2.conf"
t_false "its entry is gone" grep -q '^///2 | ' "$T/boot/limine.conf"
t_eq "the old kernel left the store" "$(find "$T/boot/gnomarchy/store" -type f | wc -l)" "2"

echo "--- a snapshot without the ESP's kernel gets no entry"
add_snapshot 7 "2026-10-28 21:00:00" "foreign kernel" "${KVERS[2]}"
t_true "snapshot-add still succeeds" "$BOOT" snapshot-add 7 2>"$T/log"
t_false "but records nothing" test -e "$T/boot/gnomarchy/entries/7.conf"
t_true "and says why" grep -q "does not contain the ESP's vmlinuz-linux" "$T/log"

echo "--- a base command line without subvol=@"
new_tree
"$BOOT" update
echo 'root=UUID=1111-2222 rw quiet' >"$T/etc/kernel/cmdline"
add_snapshot 2 "2026-10-27 09:15:00" "x"
t_false "snapshot-add refuses" "$BOOT" snapshot-add 2
t_false "and records nothing" test -e "$T/boot/gnomarchy/entries/2.conf"
t_true "the menu still updates" "$BOOT" update

echo "--- the ESP budget drops the oldest entries"
PAD_KB=100
new_tree
export GNOMARCHY_BOOT_ESP_SIZE_KB=900
add_snapshot 2 "2026-10-27 09:00:00" "a"
"$BOOT" snapshot-add 2
set_esp_kernel "${KVERS[1]}"
add_snapshot 3 "2026-10-27 10:00:00" "b" "${KVERS[1]}"
"$BOOT" snapshot-add 3
t_true "two snapshots fit" test -e "$T/boot/gnomarchy/entries/2.conf"
set_esp_kernel "${KVERS[2]}"
add_snapshot 4 "2026-10-27 11:00:00" "c" "${KVERS[2]}"
"$BOOT" snapshot-add 4 2>"$T/log"
t_false "the third pushes out the oldest" test -e "$T/boot/gnomarchy/entries/2.conf"
t_true "the newer two remain" test -e "$T/boot/gnomarchy/entries/3.conf" -a -e "$T/boot/gnomarchy/entries/4.conf"
t_true "the snapshot itself is untouched" test -d "$T/.snapshots/2/snapshot"
t_true "the drop is reported" grep -q "dropping the menu entry of snapshot 2" "$T/log"
unset GNOMARCHY_BOOT_ESP_SIZE_KB
PAD_KB=0

echo "--- the snapper plugin"
new_tree
export GNOMARCHY_BOOT_BIN="$BOOT"
PLUGIN="$REPO/default/boot/50-gnomarchy-boot"
add_snapshot 5 "2026-10-28 08:00:00" "via plugin"
t_true "create-snapshot-post for / succeeds" bash "$PLUGIN" create-snapshot-post / btrfs 5
t_true "and adds the entry" grep -q '^///5 | ' "$T/boot/limine.conf"
add_snapshot 8 "2026-10-28 08:00:00" "home"
bash "$PLUGIN" create-snapshot-post /home btrfs 8
t_false "other subvolumes are ignored" test -e "$T/boot/gnomarchy/entries/8.conf"
t_true "pre events are ignored" bash "$PLUGIN" create-snapshot-pre / btrfs 9
t_true "delete-snapshot-post removes" bash "$PLUGIN" delete-snapshot-post / btrfs 5
t_false "the entry is gone" grep -q '^///5 | ' "$T/boot/limine.conf"
unset GNOMARCHY_BOOT_BIN
```

- [ ] **Step 2: Write the golden file `iso/tests/fixtures/boot/snapshots.conf`**

```text
# Generated by gnomarchy-boot; rewritten on every kernel update, snapshot and
# theme change. Edit /etc/kernel/cmdline, not this file.
timeout: 3
default_entry: Gnomarchy/linux
interface_branding: Gnomarchy
interface_branding_colour: 7aa2f7
term_palette: 15161e;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;a9b1d6
term_palette_bright: 414868;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;c0caf5
term_background: 001a1b26
term_foreground: c0caf5

/+Gnomarchy
//linux
    protocol: linux
    kernel_path: boot():/vmlinuz-linux#<vmlinuz 6.17.6-arch1-1>
    module_path: boot():/initramfs-linux.img#<initramfs 6.17.6-arch1-1>
    kernel_cmdline: root=UUID=1111-2222 rw rootflags=subvol=@ quiet splash
//Snapshots
///4 | 2026-10-28 18:30 | manual
    protocol: linux
    kernel_path: boot():/gnomarchy/store/<vmlinuz 6.17.6-arch1-1>#<vmlinuz 6.17.6-arch1-1>
    module_path: boot():/gnomarchy/store/<initramfs 6.17.6-arch1-1>#<initramfs 6.17.6-arch1-1>
    kernel_cmdline: root=UUID=1111-2222 ro rootflags=subvol=@snapshots/4/snapshot quiet systemd.volatile=overlay gnomarchy.snapshot=4
///3 | 2026-10-28 14:02 | pacman -Syu
    protocol: linux
    kernel_path: boot():/gnomarchy/store/<vmlinuz 6.17.6-arch1-1>#<vmlinuz 6.17.6-arch1-1>
    module_path: boot():/gnomarchy/store/<initramfs 6.17.6-arch1-1>#<initramfs 6.17.6-arch1-1>
    kernel_cmdline: root=UUID=1111-2222 ro rootflags=subvol=@snapshots/3/snapshot quiet systemd.volatile=overlay gnomarchy.snapshot=3
///2 | 2026-10-27 09:15 | before upgrade
    protocol: linux
    kernel_path: boot():/gnomarchy/store/<vmlinuz 6.17.5-arch1-1>#<vmlinuz 6.17.5-arch1-1>
    module_path: boot():/gnomarchy/store/<initramfs 6.17.5-arch1-1>#<initramfs 6.17.5-arch1-1>
    kernel_cmdline: root=UUID=1111-2222 ro rootflags=subvol=@snapshots/2/snapshot quiet systemd.volatile=overlay gnomarchy.snapshot=2
```

- [ ] **Step 3: Run it to see the new cases fail**

Run: `bash iso/tests/test-boot-config.sh`
Expected: Task 2's cases PASS; "snapshot 2 is added" FAILs (`boot_snapshot_add: command not found`).

- [ ] **Step 4: Write `default/boot/lib/snapshots.sh`**

```bash
#!/bin/bash
# Snapshot menu records, the content-addressed store on the ESP, and the ESP
# budget. Called from snapper's plugin, which must finish within seconds and
# must not call snapper, so everything here reads snapper's files directly.

# boot_info_field FILE TAG — one element of snapper's info.xml, entities decoded.
boot_info_field() {
  sed -n "/<$2>/{s:.*<$2>\(.*\)</$2>.*:\1:p;q}" "$1" |
    sed -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e "s/&apos;/'/g" -e 's/&amp;/\&/g'
}

# Printable, one line, at most 60 characters: it becomes a menu title.
boot_clean_text() {
  local s="${1//[^[:print:]]/ }"
  printf '%s' "${s:0:60}"
}

# boot_snapshot_kernel_version N KERNEL — the module version inside snapshot N
# whose vmlinuz is byte for byte the ESP's vmlinuz-KERNEL.
boot_snapshot_kernel_version() {
  local want dir
  want="$(boot_hash "$BOOT_ESP/vmlinuz-$2")" || return 1
  for dir in "$BOOT_SNAPSHOTS/$1/snapshot/usr/lib/modules"/*/; do
    [[ -f "${dir}vmlinuz" ]] || continue
    if [[ "$(boot_hash "${dir}vmlinuz")" == "$want" ]]; then
      dir="${dir%/}"
      printf '%s\n' "${dir##*/}"
      return 0
    fi
  done
  return 1
}

# boot_store_put FILE HASH — copy once; ten snapshots of one kernel share it.
boot_store_put() {
  mkdir -p "$BOOT_STORE"
  [[ -f "$BOOT_STORE/$2" ]] && return 0
  cp "$1" "$BOOT_STORE/$2.tmp"
  mv -f "$BOOT_STORE/$2.tmp" "$BOOT_STORE/$2"
}

boot_snapshot_add() {
  local n="$1" info kernel version kh ih date desc base
  if [[ ! "$n" =~ ^[1-9][0-9]*$ ]]; then
    boot_log "snapshot number must be a positive integer, got '$n'"
    return 1
  fi
  info="$BOOT_SNAPSHOTS/$n/info.xml"
  if [[ ! -f "$info" || ! -d "$BOOT_SNAPSHOTS/$n/snapshot" ]]; then
    boot_log "snapshot $n not found in $BOOT_SNAPSHOTS"
    return 1
  fi
  base="$(boot_base_cmdline)" || return 1
  boot_snapshot_cmdline "$base" "$n" >/dev/null || return 1
  kernel="$(boot_default_kernel)" || return 1

  # The ESP holds the kernel this snapshot runs: snap-pac's pre snapshot is
  # taken before the transaction, its post snapshot after mkinitcpio's hook.
  if ! version="$(boot_snapshot_kernel_version "$n" "$kernel")"; then
    boot_log "snapshot $n does not contain the ESP's vmlinuz-$kernel; it gets no menu entry"
    return 0
  fi

  kh="$(boot_hash "$BOOT_ESP/vmlinuz-$kernel")"
  ih="$(boot_hash "$BOOT_ESP/initramfs-$kernel.img")"
  boot_store_put "$BOOT_ESP/vmlinuz-$kernel" "$kh"
  boot_store_put "$BOOT_ESP/initramfs-$kernel.img" "$ih"

  date="$(boot_info_field "$info" date)"
  if [[ -z "$date" ]] || ! date="$(date -d "$date UTC" '+%Y-%m-%d %H:%M')"; then
    boot_log "snapshot $n: no readable date in $info"
    return 1
  fi
  desc="$(boot_clean_text "$(boot_info_field "$info" description)")"

  mkdir -p "$BOOT_ENTRIES"
  printf 'KERNEL=%s\nVERSION=%s\nKERNEL_HASH=%s\nINITRAMFS_HASH=%s\nDATE=%s\nDESCRIPTION=%s\n' \
    "$kernel" "$version" "$kh" "$ih" "$date" "$desc" >"$BOOT_ENTRIES/$n.conf.tmp"
  mv -f "$BOOT_ENTRIES/$n.conf.tmp" "$BOOT_ENTRIES/$n.conf"
  boot_log "snapshot $n added to the boot menu (kernel $version)"
  boot_enforce_budget
}

boot_snapshot_remove() {
  if [[ ! "$1" =~ ^[1-9][0-9]*$ ]]; then
    boot_log "snapshot number must be a positive integer, got '$1'"
    return 1
  fi
  rm -f "$BOOT_ENTRIES/$1.conf"
  boot_store_gc
}

# Delete store files no record refers to.
boot_store_gc() {
  local f name
  local -A keep=() e=()
  for f in "$BOOT_ENTRIES"/*.conf; do
    [[ -f "$f" ]] || continue
    e=()
    boot_read_kv "$f" e
    [[ -n "${e[KERNEL_HASH]:-}" ]] && keep["${e[KERNEL_HASH]}"]=1
    [[ -n "${e[INITRAMFS_HASH]:-}" ]] && keep["${e[INITRAMFS_HASH]}"]=1
  done
  for f in "$BOOT_STORE"/*; do
    [[ -f "$f" ]] || continue
    name="${f##*/}"
    if [[ -z "${keep[$name]:-}" ]]; then
      rm -f "$f"
      boot_log "removed ${name:0:12} from the store; no snapshot uses it"
    fi
  done
}

# Percent of the ESP in use. GNOMARCHY_BOOT_ESP_SIZE_KB exists for the tests,
# whose ESP is a plain directory.
boot_esp_usage() {
  local used
  if [[ -n "${GNOMARCHY_BOOT_ESP_SIZE_KB:-}" ]]; then
    used="$(du -sk --apparent-size "$BOOT_ESP" | cut -f1)"
    printf '%s\n' $((used * 100 / GNOMARCHY_BOOT_ESP_SIZE_KB))
  else
    df -P "$BOOT_ESP" | awk 'NR == 2 { sub("%", "", $5); print $5 }'
  fi
}

# Keep the ESP at or under 80%: drop menu entries oldest first. The snapshots
# themselves stay and can still be restored from a running system.
boot_enforce_budget() {
  local -a numbers
  while (($(boot_esp_usage) > 80)); do
    mapfile -t numbers < <(boot_snapshot_numbers)
    if ((${#numbers[@]} <= 1)); then
      boot_log "the ESP is over 80% full with one snapshot entry left; keeping it"
      return 0
    fi
    boot_log "the ESP is over 80% full: dropping the menu entry of snapshot ${numbers[-1]} (the snapshot itself is kept)"
    rm -f "$BOOT_ENTRIES/${numbers[-1]}.conf"
    boot_store_gc
  done
}
```

- [ ] **Step 5: Write `default/boot/50-gnomarchy-boot`**

```bash
#!/bin/bash
# snapper plugin: keeps the Limine menu in step with the root config.
#
# snapper runs every executable in /usr/lib/snapper/plugins as
#   <event> <subvolume> <fstype> [<snapshot number>]
# and treats a non-zero exit as an error it reports. Plugins must not call
# snapper and must finish within seconds; gnomarchy-boot reads snapper's files.
set -euo pipefail

BOOT="${GNOMARCHY_BOOT_BIN:-/usr/local/lib/gnomarchy/boot/gnomarchy-boot}"

event="${1:-}"
subvolume="${2:-}"
[[ "$subvolume" == / ]] || exit 0

case "$event" in
  create-snapshot-post) exec "$BOOT" snapshot-add "${4:?no snapshot number}" ;;
  delete-snapshot-post) exec "$BOOT" snapshot-remove "${4:?no snapshot number}" ;;
  create-config-post) exec "$BOOT" update ;;
esac
exit 0
```

- [ ] **Step 6: Run the tests to see them pass**

Run `chmod +x default/boot/50-gnomarchy-boot`, then `bash iso/tests/test-boot-config.sh`.
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add default/boot/lib/snapshots.sh default/boot/50-gnomarchy-boot \
  iso/tests/test-boot-config.sh iso/tests/fixtures/boot/snapshots.conf
git update-index --chmod=+x default/boot/50-gnomarchy-boot
git commit -m "feat(boot): snapshot menu entries, store, ESP budget and snapper plugin"
```

---

### Task 4: Installing Limine, the snapper config, restore

**Files:**
- Create: `default/boot/lib/install.sh`, `default/boot/lib/snapper.sh`, `default/boot/lib/restore.sh`
- Modify: `default/boot/gnomarchy-boot` (plain `source` lines), `iso/tests/test-boot-config.sh`

**Interfaces:**
- Consumes: `boot_read_kv`, `boot_default_kernel`, `boot_snapshot_kernel_version`, `boot_write_conf`.
- Produces: `boot_install`, `boot_snapper_init`, `boot_restore N`, `boot_delete_subvolume TOP RELPATH`.
- `/etc/gnomarchy/boot.conf` keys: `DISK=/dev/…`, `ESP_PART=2`, `ENCRYPTED=0|1`.
- Test-only env: `GNOMARCHY_BOOT_EFIVARS` (default `/sys/firmware/efi/efivars`).

`restore` needs a real btrfs and is proven by the third CI boot (Task 10), not here.

- [ ] **Step 1: Add the failing cases to `iso/tests/test-boot-config.sh`** (before `t_done`)

```bash
# stub NAME SCRIPT — a fake command in $T/bin that logs its arguments.
stub() {
  mkdir -p "$T/bin"
  printf '#!/bin/bash\necho "%s $*" >>"%s/calls"\n%s\n' "$1" "$T" "$2" >"$T/bin/$1"
  chmod +x "$T/bin/$1"
}

echo "--- install: Limine onto the ESP and the disk"
new_tree
mkdir -p "$T/usr/share/limine" "$T/efivars"
printf 'efi x64\n' >"$T/usr/share/limine/BOOTX64.EFI"
printf 'efi ia32\n' >"$T/usr/share/limine/BOOTIA32.EFI"
printf 'bios stage 2\n' >"$T/usr/share/limine/limine-bios.sys"
printf 'DISK=/dev/fake\nESP_PART=2\nENCRYPTED=0\n' >"$T/etc/gnomarchy/boot.conf"
stub limine ''
stub efibootmgr ''
export GNOMARCHY_BOOT_EFIVARS="$T/efivars"
PATH="$T/bin:$PATH" "$BOOT" install
t_true "fallback EFI path" cmp -s "$T/usr/share/limine/BOOTX64.EFI" "$T/boot/EFI/BOOT/BOOTX64.EFI"
t_true "32-bit EFI path" cmp -s "$T/usr/share/limine/BOOTIA32.EFI" "$T/boot/EFI/BOOT/BOOTIA32.EFI"
t_true "NVRAM target path" cmp -s "$T/usr/share/limine/BOOTX64.EFI" "$T/boot/EFI/limine/BOOTX64.EFI"
t_true "BIOS stage 2 on the ESP" cmp -s "$T/usr/share/limine/limine-bios.sys" "$T/boot/limine-bios.sys"
t_true "limine bios-install ran on the disk" grep -qx "limine bios-install /dev/fake" "$T/calls"
t_true "an NVRAM entry was created" \
  grep -qxF 'efibootmgr --create --disk /dev/fake --part 2 --loader \EFI\limine\BOOTX64.EFI --label Gnomarchy' "$T/calls"
rm "$T/calls"
stub efibootmgr '[[ $# -eq 0 ]] && printf "Boot0001* Gnomarchy\tHD(2,GPT)\n"; exit 0'
PATH="$T/bin:$PATH" "$BOOT" install
t_false "an existing NVRAM entry is kept" grep -q -- "--create" "$T/calls"
rm -rf "$T/efivars" "$T/calls"
PATH="$T/bin:$PATH" "$BOOT" install
t_false "no NVRAM work on BIOS firmware" grep -q '^efibootmgr' "$T/calls"
t_true "bios-install still runs on BIOS firmware" grep -qx "limine bios-install /dev/fake" "$T/calls"
rm "$T/etc/gnomarchy/boot.conf"
t_false "install refuses without boot.conf" env PATH="$T/bin:$PATH" "$BOOT" install
unset GNOMARCHY_BOOT_EFIVARS

echo "--- snapper-init: root config and snapshot 1, no D-Bus"
new_tree
mkdir -p "$T/usr/share/snapper/config-templates"
printf '%s\n' 'SUBVOLUME="/"' 'FSTYPE="btrfs"' 'ALLOW_GROUPS=""' 'TIMELINE_CREATE="yes"' \
  'NUMBER_LIMIT="50"' 'NUMBER_LIMIT_IMPORTANT="10"' >"$T/usr/share/snapper/config-templates/default"
stub snapper ''
stub systemctl ''
PATH="$T/bin:$PATH" "$BOOT" snapper-init
for kv in 'TIMELINE_CREATE="no"' 'NUMBER_LIMIT="10"' 'NUMBER_LIMIT_IMPORTANT="5"' 'ALLOW_GROUPS="wheel"'; do
  t_true "root config: $kv" grep -qxF "$kv" "$T/etc/snapper/configs/root"
done
t_true "SNAPPER_CONFIGS lists root" grep -qx 'SNAPPER_CONFIGS="root"' "$T/etc/conf.d/snapper"
t_true "the cleanup timer is enabled" grep -qx "systemctl enable snapper-cleanup.timer" "$T/calls"
t_true "snapshot 1 is created without D-Bus" \
  grep -qxF "snapper --no-dbus -c root create --description Gnomarchy installed" "$T/calls"
rm "$T/calls"
stub snapper '[[ " $* " == *" list "* ]] && echo "Gnomarchy installed"; exit 0'
PATH="$T/bin:$PATH" "$BOOT" snapper-init
t_false "a second run creates no second snapshot" grep -q " create " "$T/calls"
```

- [ ] **Step 2: Run it to see the new cases fail**

Run: `bash iso/tests/test-boot-config.sh`
Expected: install cases FAIL (`boot_install: command not found`).

- [ ] **Step 3: Write `default/boot/lib/install.sh`**

```bash
#!/bin/bash
# Limine onto the ESP and the disk. Run by the installer and by the pacman
# hook whenever the limine package changes.

boot_install() {
  local disk efivars="${GNOMARCHY_BOOT_EFIVARS:-/sys/firmware/efi/efivars}"
  local -A conf=()
  boot_read_kv "$BOOT_CONF" conf || boot_die "no $BOOT_CONF; the installer writes it"
  disk="${conf[DISK]:-}"
  [[ -n "$disk" ]] || boot_die "$BOOT_CONF has no DISK="
  [[ -b "$disk" || -n "$BOOT_ROOT" ]] || boot_die "$disk from $BOOT_CONF is not a block device"
  [[ -f "$BOOT_LIMINE_SHARE/BOOTX64.EFI" ]] || boot_die "limine is not installed: no $BOOT_LIMINE_SHARE/BOOTX64.EFI"

  # UEFI. The removable-media path boots on any firmware; the NVRAM entry
  # below is a nicety on top of it.
  install -Dm644 "$BOOT_LIMINE_SHARE/BOOTX64.EFI" "$BOOT_ESP/EFI/BOOT/BOOTX64.EFI"
  install -Dm644 "$BOOT_LIMINE_SHARE/BOOTIA32.EFI" "$BOOT_ESP/EFI/BOOT/BOOTIA32.EFI"
  install -Dm644 "$BOOT_LIMINE_SHARE/BOOTX64.EFI" "$BOOT_ESP/EFI/limine/BOOTX64.EFI"

  # BIOS, whatever the firmware: the disk has a BIOS boot partition, so it
  # boots both ways, including after a move to another machine.
  install -Dm644 "$BOOT_LIMINE_SHARE/limine-bios.sys" "$BOOT_ESP/limine-bios.sys"
  limine bios-install "$disk"

  if [[ -d "$efivars" ]]; then
    if efibootmgr | grep -qE '^Boot[0-9A-Fa-f]{4}\*? Gnomarchy([[:space:]]|$)'; then
      boot_log "the NVRAM entry Gnomarchy is already there"
    elif efibootmgr --create --disk "$disk" --part "${conf[ESP_PART]:-2}" \
      --loader '\EFI\limine\BOOTX64.EFI' --label Gnomarchy >/dev/null; then
      boot_log "created the NVRAM entry Gnomarchy"
    else
      boot_log "warning: no NVRAM entry written; the firmware still boots EFI/BOOT/BOOTX64.EFI"
    fi
  fi
}
```

- [ ] **Step 4: Write `default/boot/lib/snapper.sh`**

```bash
#!/bin/bash
# The root snapper config and snapshot 1, without D-Bus.
#
# `snapper create-config` needs snapperd over D-Bus, which arch-chroot does not
# have, and refuses a /.snapshots that already exists - ours is the @snapshots
# subvolume. So the config is written from snapper's own template. Run last in
# the installation: snap-pac does nothing until this config exists.

boot_snapper_init() {
  local template="$BOOT_ROOT/usr/share/snapper/config-templates/default"
  local config="$BOOT_ROOT/etc/snapper/configs/root"
  local confd="$BOOT_ROOT/etc/conf.d/snapper"
  local kv

  [[ -f "$template" ]] || boot_die "snapper is not installed: no $template"

  if [[ ! -f "$config" ]]; then
    install -Dm640 "$template" "$config"
    sed -i \
      -e 's|^SUBVOLUME=.*|SUBVOLUME="/"|' \
      -e 's|^FSTYPE=.*|FSTYPE="btrfs"|' \
      -e 's|^ALLOW_GROUPS=.*|ALLOW_GROUPS="wheel"|' \
      -e 's|^TIMELINE_CREATE=.*|TIMELINE_CREATE="no"|' \
      -e 's|^NUMBER_LIMIT=.*|NUMBER_LIMIT="10"|' \
      -e 's|^NUMBER_LIMIT_IMPORTANT=.*|NUMBER_LIMIT_IMPORTANT="5"|' \
      "$config"
    for kv in 'SUBVOLUME="/"' 'FSTYPE="btrfs"' 'ALLOW_GROUPS="wheel"' 'TIMELINE_CREATE="no"' \
      'NUMBER_LIMIT="10"' 'NUMBER_LIMIT_IMPORTANT="5"'; do
      grep -qxF "$kv" "$config" || boot_die "snapper's template has no ${kv%%=*} line; check $config"
    done
    boot_log "wrote $config"
  fi

  if [[ ! -f "$confd" ]] || ! grep -qE '^SNAPPER_CONFIGS="(.* )?root( .*)?"$' "$confd"; then
    install -Dm644 /dev/null "$confd"
    printf 'SNAPPER_CONFIGS="root"\n' >"$confd"
  fi

  systemctl enable snapper-cleanup.timer

  # Snapshot 1 has no cleanup algorithm, so number cleanup never removes it.
  if ! snapper --no-dbus --csvout --no-headers -c root list --columns description |
    grep -qxF 'Gnomarchy installed'; then
    snapper --no-dbus -c root create --description 'Gnomarchy installed'
  fi
}
```

The stub logs `--description Gnomarchy installed` because `$*` joins
arguments with spaces; the real call passes the description as one argument.

- [ ] **Step 5: Write `default/boot/lib/restore.sh`**

```bash
#!/bin/bash
# Make snapshot N the root filesystem from the next boot on. The same steps
# work whether the running system is @ or snapshot N itself.

# boot_delete_subvolume TOP RELPATH — a subvolume and every subvolume nested in
# it (systemd creates var/lib/machines and var/lib/portables as subvolumes, and
# a subvolume that holds others cannot be deleted).
boot_delete_subvolume() {
  local top="$1" rel="$2" child
  while IFS= read -r child; do
    [[ -n "$child" ]] && boot_delete_subvolume "$top" "$child"
  done < <(btrfs subvolume list -o "$top/$rel" | sed -n 's/^.* path //p')
  btrfs subvolume delete "$top/$rel"
}

boot_restore() {
  local n="$1" kernel source top backup stamp h
  local -A e=()
  [[ "$n" =~ ^[1-9][0-9]*$ ]] || boot_die "restore needs a snapshot number, got '$n'"
  [[ -d "$BOOT_SNAPSHOTS/$n/snapshot" ]] || boot_die "no snapshot $n in $BOOT_SNAPSHOTS"

  if boot_read_kv "$BOOT_ENTRIES/$n.conf" e; then
    for h in "${e[KERNEL_HASH]:-}" "${e[INITRAMFS_HASH]:-}"; do
      [[ -n "$h" && -f "$BOOT_STORE/$h" ]] || boot_die "snapshot $n's boot files are missing from $BOOT_STORE"
    done
  else
    # No menu record (the ESP budget dropped it): the restored root can only
    # boot the kernel already on the ESP, so the snapshot must hold its modules.
    kernel="$(boot_default_kernel)" || exit 1
    boot_snapshot_kernel_version "$n" "$kernel" >/dev/null ||
      boot_die "snapshot $n has no boot entry and lacks the installed kernel's modules; it would not boot"
  fi

  source="$(findmnt -no SOURCE "$BOOT_ROOT/.snapshots")" || boot_die "/.snapshots is not mounted"
  source="${source%%[*}"
  top="$BOOT_ROOT/run/gnomarchy/btrfs-top"
  mkdir -p "$top"
  mount -o subvolid=5 "$source" "$top"
  # Leave nothing mounted, whatever happens below. Expanded now: $top is
  # local and out of scope by the time the EXIT trap runs.
  # shellcheck disable=SC2064
  trap "umount '$top'" EXIT

  for backup in "$top"/@restore-backup-*; do
    [[ -d "$backup" ]] || continue
    boot_log "deleting the previous backup ${backup##*/}"
    boot_delete_subvolume "$top" "${backup##*/}"
  done

  stamp="$(date +%Y%m%d-%H%M%S)"
  mv "$top/@" "$top/@restore-backup-$stamp"
  btrfs subvolume snapshot "$top/@snapshots/$n/snapshot" "$top/@"
  boot_log "snapshot $n is now @; the previous root is kept as @restore-backup-$stamp"

  if [[ -n "${e[KERNEL]:-}" ]]; then
    install -m644 "$BOOT_STORE/${e[KERNEL_HASH]}" "$BOOT_ESP/vmlinuz-${e[KERNEL]}"
    install -m644 "$BOOT_STORE/${e[INITRAMFS_HASH]}" "$BOOT_ESP/initramfs-${e[KERNEL]}.img"
  fi
  boot_write_conf
}
```

`btrfs subvolume list -o` prints `path` relative to the filesystem top level,
which is what `$top` is mounted at, so the recursion's `$top/$child` is right.

- [ ] **Step 6: Make the library loading in `default/boot/gnomarchy-boot` unconditional**

Replace the temporary loop:

```bash
for lib in snapshots install snapper restore; do
  # Later tasks add these; until then their subcommands are unavailable.
  # shellcheck source=/dev/null
  [[ -f "$BOOT_LIB/$lib.sh" ]] && source "$BOOT_LIB/$lib.sh"
done
```

with:

```bash
# shellcheck source=lib/snapshots.sh
source "$BOOT_LIB/snapshots.sh"
# shellcheck source=lib/install.sh
source "$BOOT_LIB/install.sh"
# shellcheck source=lib/snapper.sh
source "$BOOT_LIB/snapper.sh"
# shellcheck source=lib/restore.sh
source "$BOOT_LIB/restore.sh"
```

- [ ] **Step 7: Run all fast tests**

Run: `bash iso/tests/unit.sh --deps` (container)
Expected: every test file PASS and shellcheck clean. Fix every shellcheck
warning in the code; disable one only with a comment saying why it is wrong.

- [ ] **Step 8: Commit**

```bash
git add default/boot/lib/install.sh default/boot/lib/snapper.sh default/boot/lib/restore.sh \
  default/boot/gnomarchy-boot iso/tests/test-boot-config.sh
git commit -m "feat(boot): install Limine, write the snapper config, restore a snapshot"
```

---

### Task 5: System files, `deploy.sh` and the install stage

**Files:**
- Create: `default/boot/95-gnomarchy-boot.hook`, `default/boot/95-gnomarchy-limine.hook`, `default/boot/gnomarchy-overlay`, `default/boot/gnomarchy-boot-theme.path`, `default/boot/gnomarchy-boot-theme.service`, `default/boot/snapshot-notify.desktop`, `default/boot/deploy.sh`, `install/login/boot.sh`, `iso/tests/test-deploy.sh`
- Modify: `install/login/all.sh`, `install/login/plymouth.sh`, `install/login/gdm.sh`
- Delete: `install/login/limine-snapper.sh`

**Interfaces:**
- Produces: `deploy.sh` (root; `DESTDIR` for tests) installs everything under the paths in the spec's table and writes `/etc/mkinitcpio.conf.d/gnomarchy.conf` from `ENCRYPTED` in `boot.conf`. With no `boot.conf` it changes nothing and exits 0.

- [ ] **Step 1: Write the failing test `iso/tests/test-deploy.sh`**

```bash
#!/bin/bash
# deploy.sh onto a throwaway root. Needs root, a wheel group and systemctl,
# which archlinux:latest has.
set -u
cd "$(dirname "$0")/../.."
REPO="$PWD"
# shellcheck source=iso/tests/lib/assert.sh
source iso/tests/lib/assert.sh

D="$(mktemp -d)"
mkdir -p "$D/etc/gnomarchy"

echo "--- not installed from the ISO"
t_true "deploy succeeds without boot.conf" env DESTDIR="$D" bash "$REPO/default/boot/deploy.sh"
t_false "and installs nothing" test -e "$D/usr/local/lib/gnomarchy/boot/gnomarchy-boot"

echo "--- an encrypted ISO install"
printf 'DISK=/dev/vda\nESP_PART=2\nENCRYPTED=1\n' >"$D/etc/gnomarchy/boot.conf"
t_true "deploy succeeds" env DESTDIR="$D" bash "$REPO/default/boot/deploy.sh"
for f in usr/local/lib/gnomarchy/boot/gnomarchy-boot usr/lib/snapper/plugins/50-gnomarchy-boot; do
  t_true "$f is executable" test -x "$D/$f"
done
for f in usr/local/lib/gnomarchy/boot/lib/common.sh usr/local/lib/gnomarchy/boot/lib/palette.sh \
  etc/pacman.d/hooks/95-gnomarchy-boot.hook etc/pacman.d/hooks/95-gnomarchy-limine.hook \
  etc/initcpio/install/gnomarchy-overlay etc/systemd/system/gnomarchy-boot-theme.path \
  etc/systemd/system/gnomarchy-boot-theme.service etc/xdg/autostart/gnomarchy-snapshot-notify.desktop; do
  t_true "$f is installed" test -f "$D/$f"
done
t_true "the theme path unit is enabled" test -L "$D/etc/systemd/system/paths.target.wants/gnomarchy-boot-theme.path"
t_eq "the theme file is root:wheel 664" "$(stat -c '%U:%G %a' "$D/etc/gnomarchy/boot-theme.conf")" "root:wheel 664"
t_true "sd-encrypt is in HOOKS" grep -q ' sd-encrypt ' "$D/etc/mkinitcpio.conf.d/gnomarchy.conf"
t_true "gnomarchy-overlay is in HOOKS" grep -q ' gnomarchy-overlay)' "$D/etc/mkinitcpio.conf.d/gnomarchy.conf"
t_false "no autostart phase (CLAUDE.md)" grep -q X-GNOME-Autostart-Phase "$D/etc/xdg/autostart/gnomarchy-snapshot-notify.desktop"

echo "--- a second run keeps the theme and follows boot.conf"
echo 'BACKGROUND=123456' >"$D/etc/gnomarchy/boot-theme.conf"
sed -i 's/ENCRYPTED=1/ENCRYPTED=0/' "$D/etc/gnomarchy/boot.conf"
env DESTDIR="$D" bash "$REPO/default/boot/deploy.sh"
t_true "the theme file is kept" grep -qx 'BACKGROUND=123456' "$D/etc/gnomarchy/boot-theme.conf"
t_false "sd-encrypt is gone on an unencrypted install" grep -q sd-encrypt "$D/etc/mkinitcpio.conf.d/gnomarchy.conf"

rm -rf "$D"
t_done
```

- [ ] **Step 2: Run it to see it fail**

Run: `bash iso/tests/test-deploy.sh`
Expected: FAIL, `deploy.sh: No such file or directory`.

- [ ] **Step 3: Write the system files**

`default/boot/95-gnomarchy-boot.hook`:

```ini
# Regenerates the Limine menu after every transaction. Sorted after
# 90-mkinitcpio-install.hook, so it always hashes the images on the ESP.
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Operation = Remove
Target = *

[Action]
Description = Updating the Limine boot menu...
When = PostTransaction
Exec = /usr/local/lib/gnomarchy/boot/gnomarchy-boot update
```

`default/boot/95-gnomarchy-limine.hook`:

```ini
# A new limine package changes nothing on disk until its binaries are copied
# to the ESP and its stage 1 into the disk's boot sector.
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = limine

[Action]
Description = Installing the updated Limine onto the ESP and disk...
When = PostTransaction
Exec = /usr/local/lib/gnomarchy/boot/gnomarchy-boot install
```

`default/boot/gnomarchy-overlay`:

```bash
#!/bin/bash
# mkinitcpio install hook: lets a snapshot boot with systemd.volatile=overlay.
# The systemd hook ships neither the service nor the overlay module, so
# without this the parameter does nothing and a read-only snapshot boots
# read-only. systemd-fstab-generator pulls the service in when the parameter
# is set.

build() {
  add_module overlay
  add_systemd_unit systemd-volatile-root.service
}

help() {
  cat <<HELPEOF
Adds systemd-volatile-root and the overlay module, so that booting with
systemd.volatile=overlay puts a tmpfs overlay over a read-only root.
HELPEOF
}
```

`default/boot/gnomarchy-boot-theme.path`:

```ini
[Unit]
Description=Watch the Gnomarchy boot menu theme

[Path]
PathChanged=/etc/gnomarchy/boot-theme.conf

[Install]
WantedBy=paths.target
```

`default/boot/gnomarchy-boot-theme.service`:

```ini
[Unit]
Description=Recolour the Limine menu from the Gnomarchy theme

[Service]
Type=oneshot
ExecStart=/usr/local/lib/gnomarchy/boot/gnomarchy-boot update
```

`default/boot/snapshot-notify.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Gnomarchy Snapshot Notice
Comment=Says so when the system was booted from a snapshot
Exec=/usr/local/bin/gnomarchy snapshot notify
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
```

- [ ] **Step 4: Write `default/boot/deploy.sh`**

```bash
#!/bin/bash
# Installs Gnomarchy's boot tooling, root-owned, onto the system.
#
# Root must never execute scripts from a user's home, so everything that
# gnomarchy-boot, the snapper plugin and the pacman hooks run is copied out of
# the repository. Idempotent: the ISO installer runs it before installing the
# bootloader, install.sh runs it again, and so does every gnomarchy update.
#
#   sudo deploy.sh              onto /
#   DESTDIR=/tmp/x deploy.sh    onto a test tree
set -Eeuo pipefail

SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEST="${DESTDIR:-}"
[[ $EUID -eq 0 ]] || { echo "deploy.sh must run as root" >&2; exit 1; }

BOOT_CONF="$DEST/etc/gnomarchy/boot.conf"
if [[ ! -f "$BOOT_CONF" ]]; then
  echo "No $BOOT_CONF: this machine was not installed from the Gnomarchy ISO, so its bootloader is left alone."
  exit 0
fi

LIB_DIR="$DEST/usr/local/lib/gnomarchy/boot"
install -Dm755 "$SRC/gnomarchy-boot" "$LIB_DIR/gnomarchy-boot"
for f in "$SRC"/lib/*.sh; do
  install -Dm644 "$f" "$LIB_DIR/lib/${f##*/}"
done
install -Dm755 "$SRC/50-gnomarchy-boot" "$DEST/usr/lib/snapper/plugins/50-gnomarchy-boot"
install -Dm644 "$SRC/95-gnomarchy-boot.hook" "$DEST/etc/pacman.d/hooks/95-gnomarchy-boot.hook"
install -Dm644 "$SRC/95-gnomarchy-limine.hook" "$DEST/etc/pacman.d/hooks/95-gnomarchy-limine.hook"
install -Dm644 "$SRC/gnomarchy-overlay" "$DEST/etc/initcpio/install/gnomarchy-overlay"
install -Dm644 "$SRC/gnomarchy-boot-theme.path" "$DEST/etc/systemd/system/gnomarchy-boot-theme.path"
install -Dm644 "$SRC/gnomarchy-boot-theme.service" "$DEST/etc/systemd/system/gnomarchy-boot-theme.service"
install -Dm644 "$SRC/snapshot-notify.desktop" "$DEST/etc/xdg/autostart/gnomarchy-snapshot-notify.desktop"

# The initramfs. sd-encrypt only where there is something to open; plymouth
# after systemd and before the crypt hook, so the passphrase prompt is drawn.
encrypt=""
if grep -qx 'ENCRYPTED=1' "$BOOT_CONF"; then encrypt=" sd-encrypt"; fi
install -Dm644 /dev/null "$DEST/etc/mkinitcpio.conf.d/gnomarchy.conf"
cat >"$DEST/etc/mkinitcpio.conf.d/gnomarchy.conf" <<EOF
# Written by Gnomarchy's default/boot/deploy.sh from /etc/gnomarchy/boot.conf.
HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block${encrypt} filesystems fsck gnomarchy-overlay)
EOF

# The one file a user writes: gnomarchy-theme-set, as a member of wheel. It is
# parsed as data and never executed.
if [[ ! -f "$DEST/etc/gnomarchy/boot-theme.conf" ]]; then
  install -m664 -o root -g wheel /dev/null "$DEST/etc/gnomarchy/boot-theme.conf"
fi
chown root:wheel "$DEST/etc/gnomarchy/boot-theme.conf"
chmod 664 "$DEST/etc/gnomarchy/boot-theme.conf"

systemctl --root="${DEST:-/}" enable gnomarchy-boot-theme.path
echo "Boot tooling deployed."
```

- [ ] **Step 5: Run the test to see it pass**

Run: `bash iso/tests/test-deploy.sh` (container, as root)
Expected: all PASS.

- [ ] **Step 6: Write `install/login/boot.sh` and wire it in**

```bash
#!/bin/bash

gnomarchy_header "Configuring the Limine Boot Menu"

# The ISO installer already deployed the boot tooling before installing the
# bootloader; this run finds it in place and only regenerates the menu with
# the theme set in the config stage.
if [[ -f /etc/gnomarchy/boot.conf ]]; then
  sudo bash "$GNOMARCHY_PATH/default/boot/deploy.sh"
  sudo /usr/local/lib/gnomarchy/boot/gnomarchy-boot update
  gnomarchy_step "Limine menu generated"
else
  gnomarchy_warn "Not installed from the Gnomarchy ISO; the bootloader is left as it is."
fi
```

`install/login/all.sh` becomes:

```bash
#!/bin/bash

source "$GNOMARCHY_INSTALL/login/gdm.sh"
source "$GNOMARCHY_INSTALL/login/plymouth.sh"
source "$GNOMARCHY_INSTALL/login/boot.sh"
```

Delete `install/login/limine-snapper.sh`.

In `install/login/plymouth.sh`, replace the block from
`# Ensure mkinitcpio has plymouth hook if installed` through its closing `fi`
with:

```bash
# The plymouth hook is in /etc/mkinitcpio.conf.d/gnomarchy.conf, written by
# default/boot/deploy.sh. Editing HOOKS here used to insert it after `udev`,
# which a systemd HOOKS line never contains, so it never happened.
```

In `install/login/gdm.sh`, replace

```bash
if [[ -f /etc/crypttab ]] && grep -qv '^[[:space:]]*#' /etc/crypttab; then
```

with

```bash
# The root is opened from the kernel command line (rd.luks.name), so there is
# no crypttab to look at; the installer records encryption in boot.conf.
if [[ -f /etc/gnomarchy/boot.conf ]] && grep -qx 'ENCRYPTED=1' /etc/gnomarchy/boot.conf; then
```

- [ ] **Step 7: Run all fast tests**

Run: `bash iso/tests/unit.sh --deps`
Expected: all PASS, shellcheck clean.

- [ ] **Step 8: Commit**

```bash
git add default/boot/95-gnomarchy-boot.hook default/boot/95-gnomarchy-limine.hook \
  default/boot/gnomarchy-overlay default/boot/gnomarchy-boot-theme.path \
  default/boot/gnomarchy-boot-theme.service default/boot/snapshot-notify.desktop \
  default/boot/deploy.sh install/login/boot.sh install/login/all.sh \
  install/login/plymouth.sh install/login/gdm.sh iso/tests/test-deploy.sh
git rm install/login/limine-snapper.sh
git update-index --chmod=+x default/boot/deploy.sh
git commit -m "feat(boot): deploy hooks, initramfs drop-in and units; replace limine-snapper.sh"
```

---

### Task 6: User-side commands

**Files:**
- Create: `bin/gnomarchy-snapshot-restore`, `bin/gnomarchy-snapshot-notify`, `install/desktop/set-keyboard-layout.sh`
- Modify: `bin/gnomarchy`, `bin/gnomarchy-theme-set`, `bin/gnomarchy-update`, `bin/gnomarchy-first-run`

**Interfaces:**
- Consumes: `boot_palette_from_alacritty`; `/etc/gnomarchy/keyboard.conf` keys `XKB_LAYOUT=`, `XKB_VARIANT=`, `LATIN=yes|no` (written by the installer, Task 8).
- Produces: `gnomarchy snapshot restore [N] [--yes]`, `gnomarchy snapshot notify`.

These are verified in the session boots (Task 10); here, syntax and shellcheck.

- [ ] **Step 1: Theme engine writes the boot palette**

In `bin/gnomarchy-theme-set`, insert before `# 10. Run on-theme-change Hook if defined` and renumber that comment to 11:

```bash
# 10. Recolour the Limine boot menu
#
# /etc/gnomarchy/boot-theme.conf is group-writable by wheel, so no sudo is
# needed; a path unit regenerates limine.conf as root when it changes. On a
# machine not installed from the ISO the file does not exist and there is no
# Gnomarchy boot menu to recolour.
BOOT_THEME_FILE=/etc/gnomarchy/boot-theme.conf
if [[ -w "$BOOT_THEME_FILE" ]]; then
  # shellcheck source=../default/boot/lib/palette.sh
  source "$GNOMARCHY_PATH/default/boot/lib/palette.sh"
  if boot_palette="$(boot_palette_from_alacritty "$THEME_DIR/alacritty.toml")"; then
    printf '%s\n' "$boot_palette" >"$BOOT_THEME_FILE"
  else
    echo "Boot menu colours unchanged: $THEME_NAME has no complete palette."
  fi
fi
```

- [ ] **Step 2: Write `bin/gnomarchy-snapshot-restore`**

```bash
#!/bin/bash
# Make a snapshot the running system from the next boot on.
#
#   gnomarchy snapshot restore [N] [--yes]
#
# The current root is kept as @restore-backup-<time> until the next restore.
set -euo pipefail

BOOT=/usr/local/lib/gnomarchy/boot/gnomarchy-boot
n=""
yes=0
for arg in "$@"; do
  case "$arg" in
    --yes | -y) yes=1 ;;
    *) n="$arg" ;;
  esac
done

if [[ ! -x "$BOOT" ]]; then
  echo "This machine was not installed from the Gnomarchy ISO; there is no Gnomarchy boot menu to restore into." >&2
  exit 1
fi

if [[ -z "$n" ]]; then
  if ! command -v gum >/dev/null; then
    echo "Usage: gnomarchy snapshot restore <number>" >&2
    exit 1
  fi
  choice="$(sudo snapper --csvout --no-headers -c root list --columns number,date,description |
    awk -F, '$1 != 0 { printf "%-5s %s  %s\n", $1, substr($2, 1, 16), $3 }' |
    gum choose --header "Restore which snapshot?")"
  n="${choice%% *}"
fi

if [[ ! "$n" =~ ^[1-9][0-9]*$ ]]; then
  echo "Not a snapshot number: $n" >&2
  exit 1
fi

if ((!yes)); then
  gum confirm "Restore snapshot $n? The current system is kept as a backup until the next restore." || exit 1
fi

sudo "$BOOT" restore "$n"
echo "Snapshot $n will be the system after the next reboot."

if ((!yes)) && gum confirm "Reboot now?"; then
  systemctl reboot
fi
```

- [ ] **Step 3: Write `bin/gnomarchy-snapshot-notify`**

```bash
#!/bin/bash
# Started at login by /etc/xdg/autostart/gnomarchy-snapshot-notify.desktop.
# On a snapshot boot it says that changes will not survive a reboot and
# offers to make the snapshot the real system; otherwise it exits at once.
set -euo pipefail

trace() { logger -t gnomarchy-snapshot-notify -- "$*"; }

n=""
read -ra words </proc/cmdline
for word in "${words[@]}"; do
  [[ "$word" == gnomarchy.snapshot=* ]] && n="${word#*=}"
done
[[ -n "$n" ]] || exit 0

trace "booted from snapshot $n"
# --wait blocks until the notification is answered or dismissed; dismissing
# it is a normal answer, not a failure.
action="$(notify-send --app-name=Gnomarchy --icon=document-revert --urgency=critical \
  --action=restore="Restore this snapshot" --wait \
  "Booted snapshot $n" \
  "Changes made now are lost at reboot. Restore the snapshot to keep this state.")" || action=""

if [[ "$action" == restore ]]; then
  trace "restore requested for snapshot $n"
  exec gnome-terminal -- gnomarchy snapshot restore "$n"
fi
```

- [ ] **Step 4: Dispatch them from `bin/gnomarchy`**

In the `snapshot)` case, add before `*)`:

```bash
      restore)
        shift 2
        exec gnomarchy-snapshot-restore "$@"
        ;;
      notify)
        exec gnomarchy-snapshot-notify
        ;;
```

change that case's usage line to `echo "Usage: gnomarchy snapshot <create|list|restore>"`,
and the help text line to:

```
  snapshot <create|list|restore>
                               Btrfs snapshots; restore makes one the system
```

- [ ] **Step 5: Refresh the boot tooling in `bin/gnomarchy-update`**

Insert before `# --- Migrations ---`:

```bash
# --- Boot tooling ------------------------------------------------------------
# gnomarchy-boot, its snapper plugin and its pacman hooks run as root from
# root-owned copies; refresh them from the tree the pull just updated.
if [[ -f /etc/gnomarchy/boot.conf && -f "$GNOMARCHY_PATH/default/boot/deploy.sh" ]]; then
  step "Updating Boot Tooling"
  if sudo bash "$GNOMARCHY_PATH/default/boot/deploy.sh" &&
    sudo /usr/local/lib/gnomarchy/boot/gnomarchy-boot update; then
    good "Boot menu regenerated"
  else
    warn "Boot tooling update FAILED"
    note_failure "boot tooling"
  fi
fi
```

- [ ] **Step 6: Write `install/desktop/set-keyboard-layout.sh` and add it to first-run**

```bash
#!/bin/bash
# GNOME input sources from the layout picked in the installer. This writes
# dconf, so it runs from gnomarchy-first-run, never inside the chroot.

KEYBOARD_CONF=/etc/gnomarchy/keyboard.conf
if [[ -f "$KEYBOARD_CONF" ]]; then
  xkb_layout="$(sed -n 's/^XKB_LAYOUT=//p' "$KEYBOARD_CONF")"
  xkb_variant="$(sed -n 's/^XKB_VARIANT=//p' "$KEYBOARD_CONF")"
  latin="$(sed -n 's/^LATIN=//p' "$KEYBOARD_CONF")"
  source_id="${xkb_layout:-us}${xkb_variant:++$xkb_variant}"
  # A non-Latin layout keeps US first: shortcuts and Latin input stay usable.
  if [[ "$latin" == no ]]; then
    sources="[('xkb', 'us'), ('xkb', '$source_id')]"
  else
    sources="[('xkb', '$source_id')]"
  fi
  gsettings set org.gnome.desktop.input-sources sources "$sources"
  gnomarchy_step "Keyboard layout: $source_id"
fi
```

In `bin/gnomarchy-first-run`, extend the step list:

```bash
for step in set-gnome-settings set-gnome-extensions set-gnome-terminal \
  set-gnome-favorites set-gnome-hotkeys set-hardware-session set-keyboard-layout; do
```

- [ ] **Step 7: Run all fast tests**

Run: `bash iso/tests/unit.sh --deps`
Expected: all PASS, shellcheck clean for the new scripts.

- [ ] **Step 8: Commit**

```bash
git add bin/gnomarchy-snapshot-restore bin/gnomarchy-snapshot-notify bin/gnomarchy \
  bin/gnomarchy-theme-set bin/gnomarchy-update bin/gnomarchy-first-run \
  install/desktop/set-keyboard-layout.sh
git update-index --chmod=+x bin/gnomarchy-snapshot-restore bin/gnomarchy-snapshot-notify
git commit -m "feat(snapshot): restore and snapshot-boot notice; theme and layout follow"
```

---

### Task 7: Installer field rules and the layout table

**Files:**
- Create: `iso/installer/lib/form.sh`, `iso/installer/lib/keymaps.tsv`, `iso/tests/test-installer-validate.sh`

**Interfaces:**
- Produces: `valid_username S`, `valid_hostname S`, `valid_timezone S`, `keymap_fields ID` (prints `XKB_LAYOUT= XKB_VARIANT= CONSOLE_KEYMAP= CONSOLE_FONT= LATIN= LABEL=`), `keymap_load ID` (sets `KB_XKB_LAYOUT KB_XKB_VARIANT KB_CONSOLE_KEYMAP KB_CONSOLE_FONT KB_LATIN KB_LABEL`), `keymap_menu`, `keymap_id_from_menu LINE`, `installer_check_answers` (normalises the `GNOMARCHY_*` answers, fills defaults, prints all problems).
- Env: `INSTALLER_ZONEINFO` (default `/usr/share/zoneinfo`).

- [ ] **Step 1: Write `iso/installer/lib/keymaps.tsv`**

Tab-separated; `-` means empty. Every console keymap below was checked to
exist in Arch's `kbd` package; the test proves the rest.

```text
# id	xkb_layout	xkb_variant	console_keymap	console_font	latin	label
us	us	-	us	-	yes	English (US)
us-intl	us	intl	us-acentos	-	yes	English (US, international)
gb	gb	-	uk	-	yes	English (UK)
de	de	-	de-latin1	-	yes	German
ch	ch	-	de_CH-latin1	-	yes	German (Switzerland)
fr	fr	-	fr-latin1	-	yes	French
be	be	-	be-latin1	-	yes	Belgian
es	es	-	es	-	yes	Spanish
latam	latam	-	la-latin1	-	yes	Spanish (Latin America)
pt	pt	-	pt-latin1	-	yes	Portuguese
br	br	-	br-abnt2	-	yes	Portuguese (Brazil)
it	it	-	it	-	yes	Italian
nl	nl	-	nl	-	yes	Dutch
se	se	-	sv-latin1	-	yes	Swedish
no	no	-	no-latin1	-	yes	Norwegian
dk	dk	-	dk-latin1	-	yes	Danish
fi	fi	-	fi	-	yes	Finnish
pl	pl	-	pl2	-	yes	Polish
cz	cz	-	cz-qwertz	-	yes	Czech
sk	sk	-	sk-qwertz	-	yes	Slovak
hu	hu	-	hu	-	yes	Hungarian
ro	ro	-	ro	-	yes	Romanian
tr	tr	-	trq	-	yes	Turkish
ee	ee	-	et	-	yes	Estonian
lt	lt	-	lt.baltic	-	yes	Lithuanian
lv	lv	-	lv	-	yes	Latvian
ru	ru	-	ru	cyr-sun16	no	Russian
ua	ua	-	ua	cyr-sun16	no	Ukrainian
by	by	-	by	cyr-sun16	no	Belarusian
bg	bg	-	bg_bds-utf8	cyr-sun16	no	Bulgarian
gr	gr	-	gr	iso07u-16	no	Greek
jp	jp	-	jp106	-	yes	Japanese
```

Write it with real tab characters (`printf` or an editor that keeps tabs). The
test fails on any row that does not have seven tab-separated fields.

- [ ] **Step 2: Write the failing test `iso/tests/test-installer-validate.sh`**

```bash
#!/bin/bash
# The installer's field rules and keyboard table, against Arch's real kbd,
# xkeyboard-config and tzdata.
set -u
cd "$(dirname "$0")/../.."
# shellcheck source=iso/tests/lib/assert.sh
source iso/tests/lib/assert.sh
# shellcheck source=iso/installer/lib/form.sh
source iso/installer/lib/form.sh

long32="$(printf 'a%.0s' {1..32})"
for u in alice a_b x1 _svc "$long32"; do t_true "username '$u' accepted" valid_username "$u"; done
for u in root 1abc Alice "a b" "" "${long32}a" a.b; do t_false "username '$u' refused" valid_username "$u"; done

long63="$(printf 'h%.0s' {1..63})"
for h in gnomarchy citest-host a 1host "$long63"; do t_true "hostname '$h' accepted" valid_hostname "$h"; done
for h in -host host- "has space" dots.not "" "${long63}h"; do t_false "hostname '$h' refused" valid_hostname "$h"; done

for z in UTC Europe/Berlin America/Argentina/Buenos_Aires; do t_true "timezone $z accepted" valid_timezone "$z"; done
for z in Mars/Base ../../etc/passwd "Europe/Berlin "; do t_false "timezone '$z' refused" valid_timezone "$z"; done

t_false "an unknown layout id is refused" keymap_fields xx
keymap_load de
t_eq "de console keymap" "$KB_CONSOLE_KEYMAP" "de-latin1"
t_eq "de X11 layout" "$KB_XKB_LAYOUT" "de"
t_eq "de has no variant" "$KB_XKB_VARIANT" ""
t_eq "the menu line round-trips" "$(keymap_id_from_menu "$(keymap_menu | grep '^German  \[')")" "de"

# The plain-layer symbol of keycode 16 (Q on a US keyboard), from the compiled
# table, so included keymap files count.
plain_q() {
  loadkeys --mktable --quiet "$1" | awk '
    /plain_map\[NR_KEYS\]/ { on = 1; next }
    on && /};/ { exit }
    on { gsub(/[{},]/, " "); for (i = 1; i <= NF; i++) v[n++] = $i }
    END { print v[16] }'
}

evdev=/usr/share/X11/xkb/rules/evdev.lst
layouts="$(awk '/^! layout/ { s = 1; next } /^!/ { s = 0 } s { print $1 }' "$evdev")"
variants="$(awk '/^! variant/ { s = 1; next } /^!/ { s = 0 } s { sub(":", "", $2); print $2 "/" $1 }' "$evdev")"

while IFS=$'\t' read -r id layout variant keymap font latin label extra; do
  [[ "$id" == \#* || -z "$id" ]] && continue
  if [[ -z "$label" || -n "$extra" ]]; then
    t_no "row $id does not have seven tab-separated fields"
    continue
  fi
  grep -qx "$layout" <<<"$layouts" && t_ok "$id: X11 layout $layout exists" || t_no "$id: no X11 layout $layout"
  if [[ "$variant" != - ]]; then
    grep -qx "$layout/$variant" <<<"$variants" && t_ok "$id: variant $variant exists" || t_no "$id: no variant $layout/$variant"
  fi
  if [[ -z "$(find /usr/share/kbd/keymaps -name "$keymap.map.gz" -print -quit)" ]]; then
    t_no "$id: no console keymap $keymap"
  else
    q="$(plain_q "$keymap")"
    # 0xfb61..0xfb7a: KT_LETTER a..z. A Latin default layer is what makes a
    # LUKS passphrase typeable at boot.
    if [[ "$q" =~ ^0xfb(6[1-9a-f]|7[0-9a])$ ]]; then
      t_ok "$id: console keymap $keymap starts on a Latin layer"
    else
      t_no "$id: console keymap $keymap does not start on a Latin layer" "keycode 16 plain: $q"
    fi
  fi
  if [[ "$font" != - ]]; then
    ls /usr/share/kbd/consolefonts/"$font".* >/dev/null && t_ok "$id: font $font exists" || t_no "$id: no console font $font"
  fi
  [[ "$latin" == yes || "$latin" == no ]] || t_no "$id: latin must be yes or no"
done <iso/installer/lib/keymaps.tsv

echo "--- unattended answers"
answers() {
  (
    unset "${!GNOMARCHY_@}"
    for kv in "$@"; do export "${kv?}"; done
    installer_check_answers && declare -p GNOMARCHY_HOSTNAME GNOMARCHY_TIMEZONE GNOMARCHY_KEYMAP GNOMARCHY_ENCRYPT GNOMARCHY_DISK_PASSWORD
  )
}
out="$(answers GNOMARCHY_DISK=/dev/vda GNOMARCHY_USERNAME=citest GNOMARCHY_PASSWORD=pw 2>&1)"
t_true "minimal answers pass" grep -q 'GNOMARCHY_HOSTNAME="gnomarchy"' <<<"$out"
t_true "timezone defaults to UTC" grep -q 'GNOMARCHY_TIMEZONE="UTC"' <<<"$out"
t_true "keymap defaults to us" grep -q 'GNOMARCHY_KEYMAP="us"' <<<"$out"
t_true "encryption defaults to n" grep -q 'GNOMARCHY_ENCRYPT="n"' <<<"$out"
t_true "the disk password defaults to the user's" grep -q 'GNOMARCHY_DISK_PASSWORD="pw"' <<<"$out"
out="$(answers GNOMARCHY_DISK=/dev/vda GNOMARCHY_USERNAME=citest GNOMARCHY_PASSWORD=pw GNOMARCHY_ENCRYPT=Y 2>&1)"
t_true "Y is normalised to y" grep -q 'GNOMARCHY_ENCRYPT="y"' <<<"$out"
out="$(answers GNOMARCHY_USERNAME=Root GNOMARCHY_HOSTNAME=-x GNOMARCHY_KEYMAP=xx GNOMARCHY_ENCRYPT=maybe 2>&1)"
for p in GNOMARCHY_DISK GNOMARCHY_USERNAME GNOMARCHY_PASSWORD GNOMARCHY_HOSTNAME GNOMARCHY_KEYMAP GNOMARCHY_ENCRYPT; do
  t_true "a bad $p is reported" grep -q "answers: $p" <<<"$out"
done

t_done
```

- [ ] **Step 3: Run it to see it fail**

Run: `bash iso/tests/test-installer-validate.sh` (container with `--deps` packages)
Expected: `form.sh: No such file or directory`, FAILs.

- [ ] **Step 4: Write `iso/installer/lib/form.sh`**

```bash
#!/bin/bash
# Installer field rules, shared by the interactive form and the unattended
# answers. No UI and no side effects: iso/tests/test-installer-validate.sh runs
# them directly.

INSTALLER_LIB="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_KEYMAPS="$INSTALLER_LIB/keymaps.tsv"
INSTALLER_ZONEINFO="${INSTALLER_ZONEINFO:-/usr/share/zoneinfo}"

valid_username() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ && "$1" != root ]]; }

# One RFC 1123 label: letters, digits and inner hyphens, at most 63.
valid_hostname() { [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; }

valid_timezone() {
  [[ "$1" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ && -f "$INSTALLER_ZONEINFO/$1" ]]
}

# keymap_fields ID — the table row as KEY=value lines ('-' becomes empty).
keymap_fields() {
  awk -F'\t' -v id="$1" '
    !/^#/ && $1 == id {
      for (i = 3; i <= 5; i++) if ($i == "-") $i = ""
      printf "XKB_LAYOUT=%s\nXKB_VARIANT=%s\nCONSOLE_KEYMAP=%s\nCONSOLE_FONT=%s\nLATIN=%s\nLABEL=%s\n",
        $2, $3, $4, $5, $6, $7
      found = 1
      exit
    }
    END { exit !found }' "$INSTALLER_KEYMAPS"
}

# keymap_load ID — sets KB_XKB_LAYOUT, KB_XKB_VARIANT, KB_CONSOLE_KEYMAP,
# KB_CONSOLE_FONT, KB_LATIN and KB_LABEL.
keymap_load() {
  local fields line
  fields="$(keymap_fields "$1")" || return 1
  while IFS= read -r line; do
    printf -v "KB_${line%%=*}" '%s' "${line#*=}"
  done <<<"$fields"
}

# Lines for gum filter: "Label  [id]".
keymap_menu() {
  awk -F'\t' '!/^#/ && NF >= 7 { printf "%s  [%s]\n", $7, $1 }' "$INSTALLER_KEYMAPS"
}

keymap_id_from_menu() {
  local re='\[([^]]+)\]$'
  [[ "$1" =~ $re ]] && printf '%s\n' "${BASH_REMATCH[1]}"
}

# installer_check_answers — validates the GNOMARCHY_* answers read from
# gnomarchy-unattended.conf and fills the defaults. Prints every problem, not
# just the first, because each CI round trip is long.
installer_check_answers() {
  local -a problems=()
  GNOMARCHY_FULLNAME="${GNOMARCHY_FULLNAME:-}"
  GNOMARCHY_HOSTNAME="${GNOMARCHY_HOSTNAME:-gnomarchy}"
  GNOMARCHY_TIMEZONE="${GNOMARCHY_TIMEZONE:-UTC}"
  GNOMARCHY_KEYMAP="${GNOMARCHY_KEYMAP:-us}"
  GNOMARCHY_ENCRYPT="${GNOMARCHY_ENCRYPT:-n}"
  GNOMARCHY_DISK_PASSWORD="${GNOMARCHY_DISK_PASSWORD:-${GNOMARCHY_PASSWORD:-}}"

  [[ -n "${GNOMARCHY_DISK:-}" ]] || problems+=("GNOMARCHY_DISK is not set")
  valid_username "${GNOMARCHY_USERNAME:-}" ||
    problems+=("GNOMARCHY_USERNAME '${GNOMARCHY_USERNAME:-}' is not a valid username")
  [[ -n "${GNOMARCHY_PASSWORD:-}" ]] || problems+=("GNOMARCHY_PASSWORD is not set")
  valid_hostname "$GNOMARCHY_HOSTNAME" || problems+=("GNOMARCHY_HOSTNAME '$GNOMARCHY_HOSTNAME' is not a valid hostname")
  valid_timezone "$GNOMARCHY_TIMEZONE" || problems+=("GNOMARCHY_TIMEZONE '$GNOMARCHY_TIMEZONE' is not a timezone")
  keymap_fields "$GNOMARCHY_KEYMAP" >/dev/null ||
    problems+=("GNOMARCHY_KEYMAP '$GNOMARCHY_KEYMAP' is not in keymaps.tsv")
  case "${GNOMARCHY_ENCRYPT,,}" in
    y | yes) GNOMARCHY_ENCRYPT=y ;;
    n | no) GNOMARCHY_ENCRYPT=n ;;
    *) problems+=("GNOMARCHY_ENCRYPT must be y or n, got '$GNOMARCHY_ENCRYPT'") ;;
  esac

  ((${#problems[@]} == 0)) && return 0
  printf 'answers: %s\n' "${problems[@]}" >&2
  return 1
}
```

- [ ] **Step 5: Run the test to see it pass**

Run: `bash iso/tests/test-installer-validate.sh`
Expected: all PASS. If a console keymap fails the Latin-layer check, replace
it in `keymaps.tsv` with a variant whose default layer is Latin (for example
`ruwin_alt_sh-UTF-8` for Russian), confirm it exists in `kbd`, and say so in
the commit message. If `loadkeys --mktable` prints nothing in the container,
read its output by hand (`loadkeys --mktable us | head -40`) and adjust the
awk to its real format before touching the table.

- [ ] **Step 6: Commit**

```bash
git add iso/installer/lib/form.sh iso/installer/lib/keymaps.tsv iso/tests/test-installer-validate.sh
git commit -m "feat(installer): field rules, keyboard table and unattended answers"
```

---

### Task 8: The installer

**Files:**
- Create: `iso/installer/gnomarchy-install`, `iso/installer/lib/disk.sh`, `iso/installer/lib/ui.sh`, `iso/installer/lib/stages.sh`
- Modify: `iso/configs/airootfs/root/.automated_script.sh` (replace), `iso/builder/build-iso.sh`

**Interfaces:**
- Consumes: Task 7's functions; `deploy.sh`; `gnomarchy-boot install|update|snapper-init`.
- Globals set before the stages run and read by them: `DISK ESP_PART ROOT_PART FS_DEV FULLNAME USERNAME PASSWORD DISK_PASSWORD ENCRYPT(y|n) TARGET_HOSTNAME TIMEZONE KEYMAP_ID` and the `KB_*` from `keymap_load`. Stages run in subshells, so a stage must not set globals for later stages.
- Writes on the target: `/etc/kernel/cmdline`, `/etc/gnomarchy/boot.conf`, `/etc/gnomarchy/keyboard.conf`, `/etc/vconsole.conf`, `/etc/X11/xorg.conf.d/00-keyboard.conf`, `/var/log/gnomarchy-installer.log`.

The installer is exercised end to end by the smoke test (Task 9 onwards);
here, `bash -n` and shellcheck.

- [ ] **Step 1: Write `iso/installer/lib/disk.sh`**

```bash
#!/bin/bash
# Disks: which may be installed onto, and the partition names on them.

INSTALLER_MIN_DISK_BYTES=$((20 * 1024 * 1024 * 1024))

# lsblk_field FIELD LINE — one value from an `lsblk -P` line.
lsblk_field() {
  local re="(^| )$1=\"([^\"]*)\""
  if [[ "$2" =~ $re ]]; then printf '%s' "${BASH_REMATCH[2]}"; fi
}

# The disk the live system was booted from, never offered as a target.
boot_medium_disk() {
  local part parent
  # Not mounted with copytoram or PXE: then there is nothing to exclude.
  part="$(findmnt -no SOURCE /run/archiso/bootmnt)" || return 0
  parent="$(lsblk -no PKNAME "$part" | sed -n 1p)"
  printf '/dev/%s\n' "${parent:-${part#/dev/}}"
}

# disk_candidates — DEVICE<TAB>BYTES<TAB>DESCRIPTION per installable disk.
disk_candidates() {
  local boot line name size type ro model tran
  boot="$(boot_medium_disk)"
  while IFS= read -r line; do
    name="$(lsblk_field NAME "$line")"
    size="$(lsblk_field SIZE "$line")"
    type="$(lsblk_field TYPE "$line")"
    ro="$(lsblk_field RO "$line")"
    model="$(lsblk_field MODEL "$line")"
    tran="$(lsblk_field TRAN "$line")"
    [[ "$type" == disk && "$ro" == 0 ]] || continue
    [[ "$name" == /dev/zram* || "$name" == "$boot" ]] && continue
    printf '%s\t%s\t%s  %s  %s\n' "$name" "$size" \
      "$(numfmt --to=iec-i --suffix=B "$size")" "${model:-unknown model}" "$tran"
  done < <(lsblk -dnbpP -o NAME,SIZE,TYPE,RO,MODEL,TRAN)
}

# partition_path DISK N — /dev/vda 3 -> /dev/vda3, /dev/nvme0n1 3 -> /dev/nvme0n1p3
partition_path() {
  if [[ "$1" =~ [0-9]$ ]]; then printf '%sp%s\n' "$1" "$2"; else printf '%s%s\n' "$1" "$2"; fi
}

# Sets ESP_PART, ROOT_PART and FS_DEV from DISK and ENCRYPT.
disk_layout() {
  ESP_PART="$(partition_path "$DISK" 2)"
  ROOT_PART="$(partition_path "$DISK" 3)"
  FS_DEV="$ROOT_PART"
  if [[ "$ENCRYPT" == y ]]; then FS_DEV=/dev/mapper/cryptroot; fi
}
```

- [ ] **Step 2: Write `iso/installer/lib/stages.sh`**

```bash
#!/bin/bash
# The seven installation stages. Each runs in its own subshell with
# `set -Eeuo pipefail`, its output in the installer log, so a stage must not
# set anything a later stage reads; disk_layout computes all of that up front.

STAGE_FNS=(stage_partition stage_filesystems stage_base stage_configure
  stage_bootloader stage_desktop stage_finish)
STAGE_TITLES=("Partition disk" "Create filesystems" "Install base system"
  "Configure system" "Install bootloader" "Install Gnomarchy desktop"
  "First snapshot and cleanup")

BTRFS_OPTS="noatime,compress=zstd:2,space_cache=v2,discard=async"

stage_partition() {
  # Whatever an earlier attempt left holding the target.
  if mountpoint -q /mnt; then umount -R /mnt; fi
  if [[ -e /dev/mapper/cryptroot ]]; then cryptsetup close cryptroot; fi
  swapoff -a
  wipefs -af "$DISK"
  sgdisk --zap-all "$DISK"
  sgdisk -n 1:0:+1M -t 1:ef02 -c 1:"BIOS boot" "$DISK"
  sgdisk -n 2:0:+4G -t 2:ef00 -c 2:"EFI system" "$DISK"
  sgdisk -n 3:0:0 -t 3:8300 -c 3:"Gnomarchy root" "$DISK"
  partprobe "$DISK"
  udevadm settle
  [[ -b "$ROOT_PART" ]] || { echo "partition $ROOT_PART did not appear"; return 1; }
}

stage_filesystems() {
  local sub
  mkfs.vfat -F32 -n BOOT "$ESP_PART"
  if [[ "$ENCRYPT" == y ]]; then
    # --key-file=- takes stdin verbatim, so no trailing newline joins the key.
    printf '%s' "$DISK_PASSWORD" |
      cryptsetup luksFormat --batch-mode --type luks2 --pbkdf argon2id --key-file=- "$ROOT_PART"
    printf '%s' "$DISK_PASSWORD" | cryptsetup open --key-file=- "$ROOT_PART" cryptroot
  fi
  mkfs.btrfs -f -L GNOMARCHY "$FS_DEV"
  mount "$FS_DEV" /mnt
  for sub in @ @home @snapshots @var_log @var_cache; do
    btrfs subvolume create "/mnt/$sub"
  done
  umount /mnt
  mount -o "$BTRFS_OPTS,subvol=@" "$FS_DEV" /mnt
  mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache}
  mount -o "$BTRFS_OPTS,subvol=@home" "$FS_DEV" /mnt/home
  mount -o "$BTRFS_OPTS,subvol=@snapshots" "$FS_DEV" /mnt/.snapshots
  mount -o "$BTRFS_OPTS,subvol=@var_log" "$FS_DEV" /mnt/var/log
  mount -o "$BTRFS_OPTS,subvol=@var_cache" "$FS_DEV" /mnt/var/cache
  mount "$ESP_PART" /mnt/boot
}

stage_base() {
  # efibootmgr for the bootloader stage; plymouth because the initramfs HOOKS
  # name it before install.sh would have installed it.
  pacstrap -K /mnt base base-devel linux linux-firmware btrfs-progs sudo git curl \
    neovim networkmanager limine efibootmgr plymouth
  genfstab -U /mnt >>/mnt/etc/fstab
  # Mount by subvolume name only: a subvolid pins / to @, so neither a snapshot
  # nor a restored @ would mount.
  sed -i -E -e 's/,subvolid=[0-9]+//' -e 's/subvolid=[0-9]+,//' /mnt/etc/fstab
  if grep -q 'subvolid=' /mnt/etc/fstab; then
    echo "fstab still pins a subvolid"
    return 1
  fi
}

stage_configure() {
  local repo="/mnt/home/$USERNAME/.local/share/gnomarchy" cmd fs_uuid luks_uuid cmdline encrypted=0

  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime
  arch-chroot /mnt hwclock --systohc
  echo "en_US.UTF-8 UTF-8" >>/mnt/etc/locale.gen
  arch-chroot /mnt locale-gen
  echo "LANG=en_US.UTF-8" >/mnt/etc/locale.conf
  echo "$TARGET_HOSTNAME" >/mnt/etc/hostname
  cat >/mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $TARGET_HOSTNAME.localdomain $TARGET_HOSTNAME
EOF

  # Keyboard: console and initramfs (a LUKS passphrase is typed here), X11 and
  # GDM, and the record gnomarchy-first-run turns into GNOME input sources.
  {
    echo "KEYMAP=$KB_CONSOLE_KEYMAP"
    if [[ -n "$KB_CONSOLE_FONT" ]]; then echo "FONT=$KB_CONSOLE_FONT"; fi
  } >/mnt/etc/vconsole.conf
  mkdir -p /mnt/etc/X11/xorg.conf.d /mnt/etc/gnomarchy
  {
    echo 'Section "InputClass"'
    echo '    Identifier "system-keyboard"'
    echo '    MatchIsKeyboard "on"'
    echo "    Option \"XkbLayout\" \"$KB_XKB_LAYOUT\""
    if [[ -n "$KB_XKB_VARIANT" ]]; then echo "    Option \"XkbVariant\" \"$KB_XKB_VARIANT\""; fi
    echo 'EndSection'
  } >/mnt/etc/X11/xorg.conf.d/00-keyboard.conf
  printf 'XKB_LAYOUT=%s\nXKB_VARIANT=%s\nLATIN=%s\n' "$KB_XKB_LAYOUT" "$KB_XKB_VARIANT" "$KB_LATIN" \
    >/mnt/etc/gnomarchy/keyboard.conf

  echo "%wheel ALL=(ALL:ALL) ALL" >/mnt/etc/sudoers.d/10-wheel
  arch-chroot /mnt useradd -m -G wheel -s /bin/bash -c "$FULLNAME" "$USERNAME"
  printf '%s:%s\n' "$USERNAME" "$PASSWORD" | arch-chroot /mnt chpasswd
  printf 'root:%s\n' "$PASSWORD" | arch-chroot /mnt chpasswd
  arch-chroot /mnt systemctl enable NetworkManager.service

  # The repository, now rather than after the chroot step: the boot tooling
  # below is deployed from it.
  mkdir -p "$repo"
  cp -a /root/gnomarchy/. "$repo/"
  chmod +x "$repo"/bin/*
  mkdir -p /mnt/usr/local/bin
  for cmd in "$repo"/bin/gnomarchy*; do
    ln -sf "/home/$USERNAME/.local/share/gnomarchy/bin/${cmd##*/}" "/mnt/usr/local/bin/${cmd##*/}"
  done
  arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.local"

  # Boot configuration. The root is opened from the command line, so there is
  # no crypttab entry for it.
  fs_uuid="$(blkid -s UUID -o value "$FS_DEV")"
  cmdline="root=UUID=$fs_uuid rw rootflags=subvol=@ quiet splash"
  if [[ "$ENCRYPT" == y ]]; then
    luks_uuid="$(blkid -s UUID -o value "$ROOT_PART")"
    cmdline="rd.luks.name=$luks_uuid=cryptroot rd.luks.options=discard $cmdline"
    encrypted=1
  fi
  mkdir -p /mnt/etc/kernel
  printf '%s\n' "$cmdline" >/mnt/etc/kernel/cmdline
  printf 'DISK=%s\nESP_PART=2\nENCRYPTED=%s\n' "$DISK" "$encrypted" >/mnt/etc/gnomarchy/boot.conf

  arch-chroot /mnt bash "/home/$USERNAME/.local/share/gnomarchy/default/boot/deploy.sh"
  arch-chroot /mnt mkinitcpio -P
}

stage_bootloader() {
  arch-chroot /mnt /usr/local/lib/gnomarchy/boot/gnomarchy-boot install
  arch-chroot /mnt /usr/local/lib/gnomarchy/boot/gnomarchy-boot update
}

stage_desktop() {
  local repo="/mnt/home/$USERNAME/.local/share/gnomarchy" theme_dir theme_name bg cmd

  # Bundled fallback wallpapers, one directory per theme:
  # gnomarchy-theme-set resolves /usr/share/backgrounds/gnomarchy/<theme>/.
  mkdir -p /mnt/usr/share/backgrounds/gnomarchy
  for theme_dir in "$repo"/themes/*/; do
    theme_name="$(basename "$theme_dir")"
    for bg in "$theme_dir"backgrounds/*; do
      [[ -f "$bg" ]] || continue
      install -Dm644 "$bg" "/mnt/usr/share/backgrounds/gnomarchy/$theme_name/${bg##*/}"
    done
  done

  # Flatpaks into the target's storage. Optional apps: report and go on.
  if command -v flatpak >/dev/null; then
    mkdir -p /etc/flatpak/installations.d /mnt/var/lib/flatpak
    printf '[Installation "target"]\nPath=/mnt/var/lib/flatpak\nDisplayName=Target System\nStorageType=harddisk\n' \
      >/etc/flatpak/installations.d/target.conf
    if flatpak remote-add --if-not-exists --installation=target flathub https://dl.flathub.org/repo/flathub.flatpakrepo &&
      flatpak install -y --noninteractive --installation=target flathub io.github.kolunmi.Bazaar org.localsend.localsend_app; then
      echo "Flatpaks preinstalled."
    else
      echo "warning: Flatpak preinstall failed; Bazaar and LocalSend can be installed later from Flathub."
    fi
    rm -f /etc/flatpak/installations.d/target.conf
    arch-chroot /mnt flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo ||
      echo "warning: could not add Flathub on the target."
  fi

  # Passwordless sudo for install.sh, which calls sudo throughout with nobody
  # watching. Removed when this stage's subshell exits, failure included.
  echo "$USERNAME ALL=(ALL:ALL) NOPASSWD: ALL" >/mnt/etc/sudoers.d/99-gnomarchy-install
  chmod 440 /mnt/etc/sudoers.d/99-gnomarchy-install
  trap 'rm -f /mnt/etc/sudoers.d/99-gnomarchy-install' EXIT

  arch-chroot -u "$USERNAME" /mnt /bin/bash -c "
    export GNOMARCHY_PATH=\"/home/$USERNAME/.local/share/gnomarchy\"
    export GNOMARCHY_CHROOT_INSTALL=1
    export USER=\"$USERNAME\"
    export HOME=\"/home/$USERNAME\"
    export PATH=\"/usr/local/bin:/home/$USERNAME/.local/share/gnomarchy/bin:\$PATH\"
    bash /home/$USERNAME/.local/share/gnomarchy/install.sh
  "

  # install.sh may have added commands; publish them all.
  for cmd in "$repo"/bin/gnomarchy*; do
    ln -sf "/home/$USERNAME/.local/share/gnomarchy/bin/${cmd##*/}" "/mnt/usr/local/bin/${cmd##*/}"
  done
}

stage_finish() {
  # Last on purpose: snap-pac (installed by install.sh) does nothing until the
  # root config exists, so the installation's transactions left no snapshots.
  arch-chroot /mnt /usr/local/lib/gnomarchy/boot/gnomarchy-boot snapper-init
}
```

- [ ] **Step 3: Write `iso/installer/lib/ui.sh`**

```bash
#!/bin/bash
# Screens. Interactive mode draws them with gum; with UNATTENDED=1 they print
# plain lines, because CI reads them and nobody is there to answer.
# Only ASCII on screen: the live console's font has no check marks.

UI_BANNER='   ____  _   _  ___  __  __    _    ____   ____ _   ___   __
  / ___|| \ | |/ _ \|  \/  |  / \  |  _ \ / ___| | | \ \ / /
 | |  _ |  \| | | | | |\/| | / _ \ | |_) | |   | |_| |\ V /
 | |_| || |\  | |_| | |  | |/ ___ \|  _ <| |___|  _  | | |
  \____||_| \_|\___/|_|  |_/_/   \_\_| \_\\____|_| |_| |_|'

SPIN='|/-\'

ui_palette() {
  # Tokyo Night on the Linux console.
  printf '\e]P01a1b26\e]P1f7768e\e]P29ece6a\e]P3e0af68\e]P47aa2f7\e]P5bb9af7\e]P67dcfff\e]P7a9b1d6'
  printf '\e]P8414868\e]P9f7768e\e]PA9ece6a\e]PBe0af68\e]PC7aa2f7\e]PDbb9af7\e]PE7dcfff\e]PFc0caf5'
  printf '\e[0m'
}

ui_say() {
  if ((UNATTENDED)); then printf '%s\n' "$*"; else gum style --foreground 7 "$*"; fi
}

ui_warn() {
  if ((UNATTENDED)); then printf 'warning: %s\n' "$*"; else gum style --foreground 3 "$*"; fi
}

ui_header() {
  if ((UNATTENDED)); then
    printf '\n== %s ==\n' "$*"
    return
  fi
  clear
  gum style --foreground 6 --bold "$UI_BANNER"
  gum style --bold --margin "1 0" "$*"
}

installer_cancel() {
  ui_say "Installation cancelled. Nothing has been written to disk."
  exit 1
}

network_ok() { curl -sS -o /dev/null --max-time 8 https://archlinux.org/; }

# pacstrap needs the network. NetworkManager may still be bringing it up when
# the installer starts, so wait a minute before asking.
ensure_network() {
  local i choice
  for i in {1..12}; do
    network_ok && return 0
    ((UNATTENDED)) || gum spin --title "Waiting for the network..." -- sleep 5
    ((!UNATTENDED)) || sleep 5
  done
  ((!UNATTENDED)) || installer_abort "no network: pacstrap cannot download the base system"
  while :; do
    ui_header "No network connection"
    ui_say "Gnomarchy downloads the base system during installation. Connect a cable, or set up Wi-Fi."
    choice="$(gum choose "Retry" "Configure Wi-Fi" "Exit")" || installer_cancel
    case "$choice" in
      Retry) network_ok && return 0 ;;
      "Configure Wi-Fi")
        ui_say "In iwctl: station wlan0 scan, station wlan0 get-networks, station wlan0 connect <name>, then exit."
        iwctl || ui_warn "iwctl exited with an error."
        ;;
      *) installer_cancel ;;
    esac
  done
}

choose_disk() {
  local lines choice dev bytes
  mapfile -t lines < <(disk_candidates)
  ((${#lines[@]})) || installer_abort "no disk to install onto was found"
  while :; do
    ui_header "Choose a disk"
    choice="$(printf '%s\n' "${lines[@]}" | awk -F'\t' '{ printf "%-16s %s\n", $1, $3 }' |
      gum choose --header "Install Gnomarchy onto which disk? Everything on it will be erased.")" ||
      installer_cancel
    dev="${choice%% *}"
    bytes="$(printf '%s\n' "${lines[@]}" | awk -F'\t' -v d="$dev" '$1 == d { print $2 }')"
    if ((bytes < INSTALLER_MIN_DISK_BYTES)); then
      ui_warn "$dev is smaller than the 20 GiB Gnomarchy needs."
      sleep 2
      continue
    fi
    DISK="$dev"
    return 0
  done
}

run_form() {
  local choice confirm

  # Keyboard first, and switch the console to it: the passwords below are
  # then typed in the layout they will be entered in.
  ui_header "Keyboard layout"
  choice="$(keymap_menu | gum filter --header "Keyboard layout" --placeholder "Type to search" \
    --value "${KB_LABEL:-English (US)}")" || installer_cancel
  KEYMAP_ID="$(keymap_id_from_menu "$choice")"
  keymap_load "$KEYMAP_ID"
  loadkeys "$KB_CONSOLE_KEYMAP"
  if [[ -n "$KB_CONSOLE_FONT" ]]; then setfont "$KB_CONSOLE_FONT"; fi

  ui_header "About you"
  FULLNAME="$(gum input --header "Full name (optional)" --value "${FULLNAME:-}")" || installer_cancel
  while :; do
    USERNAME="$(gum input --header "Username" --value "${USERNAME:-}")" || installer_cancel
    valid_username "$USERNAME" && break
    ui_warn "Lowercase letters, digits, - and _, starting with a letter or _, at most 32, not root."
  done
  while :; do
    PASSWORD="$(gum input --password --header "Password for $USERNAME")" || installer_cancel
    confirm="$(gum input --password --header "Repeat the password")" || installer_cancel
    [[ -n "$PASSWORD" && "$PASSWORD" == "$confirm" ]] && break
    ui_warn "The passwords are empty or do not match."
  done

  ui_header "This computer"
  while :; do
    TARGET_HOSTNAME="$(gum input --header "Computer name" --value "${TARGET_HOSTNAME:-gnomarchy}")" || installer_cancel
    valid_hostname "$TARGET_HOSTNAME" && break
    ui_warn "Letters, digits and inner hyphens, at most 63."
  done
  TIMEZONE="$(timedatectl list-timezones | gum filter --header "Timezone" --placeholder "Type to search" \
    --value "${TIMEZONE:-UTC}")" || installer_cancel

  ENCRYPT=n
  DISK_PASSWORD="$PASSWORD"
  if gum confirm --default=false "Encrypt the disk with LUKS?"; then
    ENCRYPT=y
    if ! gum confirm "Use the same password to unlock the disk?"; then
      while :; do
        DISK_PASSWORD="$(gum input --password --header "Disk password")" || installer_cancel
        confirm="$(gum input --password --header "Repeat the disk password")" || installer_cancel
        [[ -n "$DISK_PASSWORD" && "$DISK_PASSWORD" == "$confirm" ]] && break
        ui_warn "The passwords are empty or do not match."
      done
    fi
  fi
}

# Returns 0 to install, 1 to edit; exits on Exit.
confirm_summary() {
  local layout="BIOS boot 1 MiB, EFI 4 GiB, Btrfs on the rest" choice desc
  [[ "$ENCRYPT" == y ]] && layout+=" (LUKS2 encrypted)"
  desc="$(disk_candidates | awk -F'\t' -v d="$DISK" '$1 == d { print $3 }')"
  ui_header "Ready to install"
  gum style --border rounded --padding "1 2" \
    "Disk       $DISK  $desc" \
    "Layout     $layout" \
    "User       ${FULLNAME:+$FULLNAME, }$USERNAME" \
    "Computer   $TARGET_HOSTNAME" \
    "Timezone   $TIMEZONE" \
    "Keyboard   $KB_LABEL"
  gum style --foreground 1 --bold "All data on $DISK will be erased."
  choice="$(gum choose "Install" "Edit" "Exit")" || installer_cancel
  case "$choice" in
    Install) return 0 ;;
    Edit) return 1 ;;
    *) installer_cancel ;;
  esac
}

# The install.sh stage currently running, from its markers in the log.
ui_substage() {
  [[ "${STAGE_FNS[$1]}" == stage_desktop ]] || return 0
  awk '/STAGE START: / { s = $0 }
    END { if (s) { sub(/.*STAGE START: /, "", s); sub(/ =+$/, "", s); print "install.sh: " s } }' "$LOG"
}

# ui_progress FRAME — redraws the stage list in place.
ui_progress() {
  local frame="$1" i mark sub last cols
  cols="$(tput cols)"
  printf '\e[H'
  printf '\e[36m%s\e[0m\e[K\n\n' "$UI_BANNER"
  for i in "${!STAGE_TITLES[@]}"; do
    case "${STAGE_STATE[i]}" in
      done) mark=$'\e[32m[ OK ]\e[0m' ;;
      run) mark=$'\e[36m[ '"${SPIN:frame%4:1}${SPIN:(frame+2)%4:1}"$' ]\e[0m' ;;
      fail) mark=$'\e[31m[FAIL]\e[0m' ;;
      *) mark=$'\e[2m[    ]\e[0m' ;;
    esac
    printf ' %s %s\e[K\n' "$mark" "${STAGE_TITLES[i]}"
    if [[ "${STAGE_STATE[i]}" == run ]]; then
      sub="$(ui_substage "$i")"
      if [[ -n "$sub" ]]; then printf '        \e[2m%s\e[0m\e[K\n' "$sub"; fi
    fi
  done
  last="$(tail -n 1 "$LOG" | tr -d '\r' | sed 's/\x1b\[[0-9;]*[A-Za-z]//g')"
  printf '\n  \e[2m%s\e[0m\e[K\n\e[J' "${last:0:$((cols - 4))}"
}
```

- [ ] **Step 4: Write `iso/installer/gnomarchy-install`**

```bash
#!/bin/bash
# The Gnomarchy installer, started on tty1 of the live ISO by
# /root/.automated_script.sh. It lives in the repository copy at
# /root/gnomarchy so it is always the revision of the configuration it installs.
#
# Interactive: a gum text UI. Unattended: answers from gnomarchy-unattended.conf
# on the boot medium or on a device labelled GNOMARCHY; plain output; a
# power-off on failure, so CI never waits out its timeout.
# Design: docs/superpowers/specs/2026-10-28-installer-limine-design.md
# shellcheck source-path=SCRIPTDIR
set -Eeuo pipefail

INSTALLER_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LOG=/var/log/gnomarchy-installer.log
UNATTENDED=0

# shellcheck source=lib/form.sh
source "$INSTALLER_DIR/lib/form.sh"
# shellcheck source=lib/disk.sh
source "$INSTALLER_DIR/lib/disk.sh"
# shellcheck source=lib/stages.sh
source "$INSTALLER_DIR/lib/stages.sh"
# shellcheck source=lib/ui.sh
source "$INSTALLER_DIR/lib/ui.sh"

STAGE_STATE=()
for _ in "${STAGE_FNS[@]}"; do STAGE_STATE+=(wait); done

copy_log_to_target() {
  if mountpoint -q /mnt/var/log; then cp "$LOG" /mnt/var/log/gnomarchy-installer.log; fi
}

# An error before any stage ran, in unattended mode: say what and power off.
installer_abort() {
  printf 'Installation aborted: %s\n' "$*" | tee -a "$LOG" >&2
  if ((UNATTENDED)); then
    # Power off rather than sit at a prompt: CI would wait out its timeout.
    systemctl poweroff
  fi
  exit 1
}

find_unattended_conf() {
  local dev mnt=/run/gnomarchy-auto
  if [[ -f /run/archiso/bootmnt/gnomarchy-unattended.conf ]]; then
    printf '%s\n' /run/archiso/bootmnt/gnomarchy-unattended.conf
    return 0
  fi
  mkdir -p "$mnt"
  # Several filesystems can carry the label (an installed system's Btrfs is
  # GNOMARCHY too), so try each. blkid exits 2 when none has it.
  while IFS= read -r dev; do
    mount -o ro "$dev" "$mnt" || continue
    if [[ -f "$mnt/gnomarchy-unattended.conf" ]]; then
      printf '%s\n' "$mnt/gnomarchy-unattended.conf"
      return 0
    fi
    umount "$mnt"
  done < <(blkid -t LABEL=GNOMARCHY -o device || true)
  return 1
}

load_unattended() {
  # shellcheck source=/dev/null
  source "$1"
  installer_check_answers || installer_abort "the answers in $1 are not valid (see above)"
  DISK="$GNOMARCHY_DISK"
  FULLNAME="$GNOMARCHY_FULLNAME"
  USERNAME="$GNOMARCHY_USERNAME"
  PASSWORD="$GNOMARCHY_PASSWORD"
  DISK_PASSWORD="$GNOMARCHY_DISK_PASSWORD"
  ENCRYPT="$GNOMARCHY_ENCRYPT"
  TARGET_HOSTNAME="$GNOMARCHY_HOSTNAME"
  TIMEZONE="$GNOMARCHY_TIMEZONE"
  KEYMAP_ID="$GNOMARCHY_KEYMAP"
  keymap_load "$KEYMAP_ID"
  [[ -b "$DISK" ]] || installer_abort "GNOMARCHY_DISK $DISK is not a block device"
  [[ "$DISK" != "$(boot_medium_disk)" ]] || installer_abort "GNOMARCHY_DISK $DISK is the installation medium"
  (($(blockdev --getsize64 "$DISK") >= INSTALLER_MIN_DISK_BYTES)) ||
    installer_abort "GNOMARCHY_DISK $DISK is smaller than 20 GiB"
}

# run_stage INDEX — runs one stage in a subshell; returns its status.
run_stage() {
  local i="$1" fn="${STAGE_FNS[$1]}" pid rc frame=0
  STAGE_STATE[i]=run
  printf '\n===== [%d/%d] %s =====\n' "$((i + 1))" "${#STAGE_FNS[@]}" "${STAGE_TITLES[i]}" >>"$LOG"
  # Statuses are taken in if/|| context: the ERR trap fires on any failing
  # command whether or not errexit is on, and a failed stage is not an
  # unexpected error. The subshell drops the trap for the same reason.
  rc=0
  if ((UNATTENDED)); then
    printf '[%d/%d] %s\n' "$((i + 1))" "${#STAGE_FNS[@]}" "${STAGE_TITLES[i]}"
    # With pipefail the pipeline fails when the stage does; tee itself does not.
    if ! (trap - ERR; set -Eeuo pipefail; "$fn") </dev/null 2>&1 | tee -a "$LOG"; then
      rc=1
    fi
  else
    (trap - ERR; set -Eeuo pipefail; "$fn") </dev/null >>"$LOG" 2>&1 &
    pid=$!
    # kill -0 only asks whether the stage is still running.
    while kill -0 "$pid" 2>/dev/null; do
      ui_progress "$frame"
      frame=$((frame + 1))
      sleep 0.2
    done
    wait "$pid" || rc=$?
  fi
  if ((rc == 0)); then STAGE_STATE[i]=done; else STAGE_STATE[i]=fail; fi
  ((UNATTENDED)) || ui_progress "$frame"
  return "$rc"
}

installer_failed() {
  local i="$1" choice
  printf '\nInstallation failed in stage %d: %s\n' "$((i + 1))" "${STAGE_TITLES[i]}" >>"$LOG"
  copy_log_to_target
  if ((UNATTENDED)); then
    printf '\nInstallation failed in stage %d (%s). Last lines of %s:\n' "$((i + 1))" "${STAGE_TITLES[i]}" "$LOG"
    tail -n 30 "$LOG"
    systemctl poweroff
    exit 1
  fi
  while :; do
    ui_header "Installation failed: ${STAGE_TITLES[i]}"
    tail -n 30 "$LOG"
    printf '\nThe full log is %s.\n\n' "$LOG"
    choice="$(gum choose "Show the full log" "Open a shell" "Power off")" || choice="Open a shell"
    case "$choice" in
      "Show the full log") gum pager <"$LOG" ;;
      "Open a shell")
        ui_say "Type exit to come back here."
        # The shell's status is the user's last command, not ours.
        bash -i || :
        ;;
      *)
        systemctl poweroff
        exit 1
        ;;
    esac
  done
}

installer_done() {
  echo "Installation complete." >>"$LOG"
  copy_log_to_target
  umount -R /mnt
  if [[ "$ENCRYPT" == y ]]; then cryptsetup close cryptroot; fi
  if ((UNATTENDED)); then
    echo "Installation complete. Rebooting."
    systemctl reboot
    exit 0
  fi
  ui_header "Gnomarchy is installed"
  ui_say "Remove the installation medium, then start your new system."
  if gum confirm "Reboot now?"; then systemctl reboot; fi
}

trap 'installer_abort "unexpected error at line $LINENO"' ERR

main() {
  local conf i
  : >"$LOG"
  ui_palette
  if conf="$(find_unattended_conf)"; then
    UNATTENDED=1
    echo "Unattended installation, answers from $conf" | tee -a "$LOG"
    load_unattended "$conf"
    ensure_network
  else
    ui_header "Welcome to Gnomarchy"
    if [[ -d /sys/firmware/efi/efivars ]]; then
      ui_say "Booted in UEFI mode. Gnomarchy installs a bootloader that also boots on BIOS."
    else
      ui_say "Booted in BIOS mode. Gnomarchy installs a bootloader that also boots on UEFI."
    fi
    sleep 2
    ensure_network
    choose_disk
    run_form
    until confirm_summary; do run_form; done
  fi

  disk_layout
  ((UNATTENDED)) || printf '\e[2J'
  for i in "${!STAGE_FNS[@]}"; do
    run_stage "$i" || installer_failed "$i"
  done
  installer_done
}

main "$@"
```

- [ ] **Step 5: Replace `iso/configs/airootfs/root/.automated_script.sh`**

```bash
#!/usr/bin/env bash
# Run by archiso's .zlogin on every login shell of the live medium. The
# installer itself lives in the repository copy at /root/gnomarchy, so it is
# always the same revision as the configuration it installs.
#
# tty1 only: archiso logs in there automatically, and a second login on
# another console, for debugging, must not start a second installer.
[[ "$(tty)" == /dev/tty1 ]] || exit 0
exec /root/gnomarchy/iso/installer/gnomarchy-install
```

- [ ] **Step 6: Keep the installer executable on the ISO**

In `iso/builder/build-iso.sh`, after
`chmod +x "$PROFILE_DIR/airootfs/root/gnomarchy/install.sh" 2>/dev/null || true` add:

```bash
# The installer is exec'd by .automated_script.sh; a lost executable bit would
# leave the live medium at a shell prompt with nothing running.
chmod 755 "$PROFILE_DIR/airootfs/root/gnomarchy/iso/installer/gnomarchy-install"
```

- [ ] **Step 7: Check syntax and run all fast tests**

Run: `bash -n iso/installer/gnomarchy-install iso/installer/lib/*.sh` then `bash iso/tests/unit.sh --deps`
Expected: no syntax errors; all PASS; shellcheck clean.

- [ ] **Step 8: Commit**

```bash
git add iso/installer/gnomarchy-install iso/installer/lib/disk.sh iso/installer/lib/ui.sh \
  iso/installer/lib/stages.sh iso/configs/airootfs/root/.automated_script.sh iso/builder/build-iso.sh
git update-index --chmod=+x iso/installer/gnomarchy-install
git commit -m "feat(installer): gum text installer with staged progress"
```

---

### Task 9: CI — fast tests, the encrypted matrix entry, offline checks

**Files:**
- Modify: `.github/workflows/install-smoke-test.yml`, `iso/tests/verify-install.sh`

**Interfaces:**
- verify-install.sh new env: `GNOMARCHY_TEST_DISK` (`/dev/nbd0`), `GNOMARCHY_TEST_HOSTNAME`, `GNOMARCHY_TEST_TIMEZONE`, `GNOMARCHY_TEST_KEYMAP`, `GNOMARCHY_TEST_ENCRYPT` (`y|n`), `GNOMARCHY_TEST_LUKS_DEV` (`/dev/nbd0p3`). Each check that needs one is skipped when it is unset.
- Mount layout adds `@snapshots` at `.snapshots`.

- [ ] **Step 1: Add the boot checks to `iso/tests/verify-install.sh`**

Insert before the final `echo` / summary lines:

```bash
# --- Boot: Limine, initramfs and snapshots ---------------------------------
# README promised snapshots in the Limine menu while nothing wrote them; the
# snapper config was never created; LUKS installs got a busybox hook in a
# systemd initramfs; plymouth was never added. Each check below is one of those.
BOOT_DIR="$ROOT/boot"
LIMINE_CONF="$BOOT_DIR/limine.conf"
CMDLINE_FILE="$ROOT/etc/kernel/cmdline"
b2() { b2sum "$1" | cut -d' ' -f1; }

cmdline=""
if [[ -f "$CMDLINE_FILE" ]]; then
  cmdline="$(<"$CMDLINE_FILE")"
  ok "/etc/kernel/cmdline exists"
else
  no "no /etc/kernel/cmdline" "gnomarchy-boot has nothing to build the menu from"
fi

if [[ -f "$LIMINE_CONF" ]]; then
  refs=0
  bad=0
  while read -r path hash; do
    refs=$((refs + 1))
    if [[ ! -f "$BOOT_DIR$path" ]]; then
      no "limine.conf points at a missing file" "$path"
      bad=$((bad + 1))
    elif [[ "$(b2 "$BOOT_DIR$path")" != "$hash" ]]; then
      no "limine.conf hash does not match" "$path"
      bad=$((bad + 1))
    fi
  done < <(sed -nE 's/^[[:space:]]*(kernel_path|module_path): boot\(\):([^#]+)#([0-9a-f]{128})$/\2 \3/p' "$LIMINE_CONF")
  unhashed="$(grep -cE '^[[:space:]]*(kernel_path|module_path): boot\(\):[^#]*$' "$LIMINE_CONF")"
  if ((refs > 0 && bad == 0 && unhashed == 0)); then
    ok "limine.conf: all $refs boot files exist and match their blake2b hashes"
  elif ((refs == 0)); then
    no "limine.conf has no hashed kernel or initramfs paths"
  elif ((unhashed > 0)); then
    no "limine.conf has $unhashed boot paths without a hash"
  fi
  grep -qx 'default_entry: Gnomarchy/linux' "$LIMINE_CONF" &&
    ok "the menu defaults to Gnomarchy/linux" || no "the menu does not default to Gnomarchy/linux"
  grep -qx 'interface_branding: Gnomarchy' "$LIMINE_CONF" && grep -q '^term_palette: ' "$LIMINE_CONF" &&
    ok "the menu carries the theme palette" || no "no theme palette in limine.conf"
  [[ -n "$cmdline" ]] && grep -qxF "    kernel_cmdline: $cmdline" "$LIMINE_CONF" &&
    ok "the kernel entry boots /etc/kernel/cmdline" || no "no entry boots /etc/kernel/cmdline"
  fs_uuid="$(findmnt -no UUID --target "$ROOT")"
  [[ -n "$fs_uuid" && " $cmdline " == *" root=UUID=$fs_uuid "* ]] &&
    ok "root=UUID matches the installed Btrfs" || no "root=UUID does not match the Btrfs UUID" "fs: $fs_uuid, cmdline: $cmdline"
else
  no "no limine.conf on the ESP"
fi

for efi in EFI/BOOT/BOOTX64.EFI EFI/limine/BOOTX64.EFI; do
  if [[ -f "$BOOT_DIR/$efi" && "$(b2 "$BOOT_DIR/$efi")" == "$(b2 "$ROOT/usr/share/limine/BOOTX64.EFI")" ]]; then
    ok "$efi is the installed Limine"
  else
    no "$efi is missing or not the installed Limine"
  fi
done
if [[ -f "$BOOT_DIR/limine-bios.sys" && "$(b2 "$BOOT_DIR/limine-bios.sys")" == "$(b2 "$ROOT/usr/share/limine/limine-bios.sys")" ]]; then
  ok "limine-bios.sys is on the ESP"
else
  no "limine-bios.sys missing from the ESP"
fi
if [[ -n "${GNOMARCHY_TEST_DISK:-}" ]]; then
  # wipefs leaves the boot code zeroed; only limine bios-install writes it.
  if (($(head -c 440 "$GNOMARCHY_TEST_DISK" | tr -d '\0' | wc -c) > 0)); then
    ok "the MBR carries boot code (limine bios-install ran)"
  else
    no "the MBR boot code is empty" "limine bios-install never ran on $GNOMARCHY_TEST_DISK"
  fi
fi
esp_dev="$(findmnt -no SOURCE --target "$BOOT_DIR")"
if [[ -n "$esp_dev" ]] && (($(blockdev --getsize64 "$esp_dev") >= 4 * 1024 * 1024 * 1024)); then
  ok "the ESP is at least 4 GiB"
else
  no "the ESP is smaller than 4 GiB" "$esp_dev"
fi

DROPIN="$ROOT/etc/mkinitcpio.conf.d/gnomarchy.conf"
if [[ -f "$DROPIN" ]]; then
  hooks=" $(sed -n 's/^HOOKS=(\(.*\))$/\1/p' "$DROPIN") "
  missing=()
  for h in systemd plymouth sd-vconsole gnomarchy-overlay; do
    [[ "$hooks" == *" $h "* ]] || missing+=("$h")
  done
  ((${#missing[@]} == 0)) && ok "initramfs HOOKS include systemd, plymouth, sd-vconsole, gnomarchy-overlay" ||
    no "initramfs HOOKS lack: ${missing[*]}" "$hooks"
  [[ "$hooks" == *" udev "* || "$hooks" == *" encrypt "* ]] &&
    no "busybox hooks in a systemd initramfs" "$hooks"
  if [[ "${GNOMARCHY_TEST_ENCRYPT:-n}" == y ]]; then
    [[ "$hooks" == *" sd-encrypt "* ]] && ok "sd-encrypt is in HOOKS" || no "an encrypted install without sd-encrypt"
  fi
else
  no "no /etc/mkinitcpio.conf.d/gnomarchy.conf"
fi
[[ -f "$ROOT/etc/initcpio/install/gnomarchy-overlay" ]] &&
  ok "the gnomarchy-overlay initcpio hook is installed" || no "no gnomarchy-overlay initcpio hook"
grep -q 'subvolid=' "$ROOT/etc/fstab" &&
  no "fstab pins subvolid=" "snapshots and a restored @ cannot mount" || ok "fstab mounts by subvolume name only"

SNAPCFG="$ROOT/etc/snapper/configs/root"
if [[ -f "$SNAPCFG" ]]; then
  for kv in 'TIMELINE_CREATE="no"' 'NUMBER_LIMIT="10"' 'ALLOW_GROUPS="wheel"'; do
    grep -qxF "$kv" "$SNAPCFG" && ok "snapper root config: $kv" || no "snapper root config lacks $kv"
  done
else
  no "no snapper root config" "snapper-init never ran"
fi
grep -qE '^SNAPPER_CONFIGS="(.* )?root( .*)?"$' "$ROOT/etc/conf.d/snapper" &&
  ok "SNAPPER_CONFIGS lists root" || no "SNAPPER_CONFIGS does not list root"
[[ -L "$ROOT/etc/systemd/system/timers.target.wants/snapper-cleanup.timer" ]] &&
  ok "snapper-cleanup.timer is enabled" || no "snapper-cleanup.timer is not enabled"
[[ -L "$ROOT/etc/systemd/system/timers.target.wants/snapper-timeline.timer" ]] &&
  no "snapper-timeline.timer is enabled" "timeline snapshots are off by design"
[[ -L "$ROOT/etc/systemd/system/paths.target.wants/gnomarchy-boot-theme.path" ]] &&
  ok "the boot-theme path unit is enabled" || no "gnomarchy-boot-theme.path is not enabled"
[[ -x "$ROOT/usr/lib/snapper/plugins/50-gnomarchy-boot" ]] &&
  ok "the snapper plugin is installed" || no "no executable snapper plugin"
for hook in 95-gnomarchy-boot.hook 95-gnomarchy-limine.hook; do
  [[ -f "$ROOT/etc/pacman.d/hooks/$hook" ]] && ok "pacman hook $hook" || no "no pacman hook $hook"
done
compgen -G "$ROOT/var/lib/pacman/local/snap-pac-[0-9]*" >/dev/null &&
  ok "snap-pac is installed" || no "snap-pac is not installed"
if grep -q '<description>Gnomarchy installed</description>' "$ROOT/.snapshots/1/info.xml" 2>/dev/null; then
  ok "snapshot 1 \"Gnomarchy installed\" exists"
else
  # The test reads .snapshots through the @snapshots mount; without it this
  # file cannot exist, which the workflow guards against.
  no "no snapshot 1 \"Gnomarchy installed\""
fi
[[ -f "$BOOT_DIR/gnomarchy/entries/1.conf" ]] && grep -q '^///1 | ' "$LIMINE_CONF" &&
  ok "snapshot 1 is in the boot menu" || no "snapshot 1 is not in the boot menu"

# --- The installer's answers ------------------------------------------------
if [[ -n "${GNOMARCHY_TEST_HOSTNAME:-}" ]]; then
  [[ "$(<"$ROOT/etc/hostname")" == "$GNOMARCHY_TEST_HOSTNAME" ]] &&
    ok "hostname is $GNOMARCHY_TEST_HOSTNAME" || no "hostname is not $GNOMARCHY_TEST_HOSTNAME" "$(<"$ROOT/etc/hostname")"
fi
if [[ -n "${GNOMARCHY_TEST_TIMEZONE:-}" ]]; then
  tz_link="$(readlink "$ROOT/etc/localtime")"
  [[ -L "$ROOT/etc/localtime" && "$tz_link" == */zoneinfo/$GNOMARCHY_TEST_TIMEZONE ]] &&
    ok "timezone is $GNOMARCHY_TEST_TIMEZONE" || no "timezone is not $GNOMARCHY_TEST_TIMEZONE" "$tz_link"
fi
if [[ -n "${GNOMARCHY_TEST_KEYMAP:-}" ]]; then
  # shellcheck source=../installer/lib/form.sh
  source "$(dirname "$0")/../installer/lib/form.sh"
  if keymap_load "$GNOMARCHY_TEST_KEYMAP"; then
    grep -qx "KEYMAP=$KB_CONSOLE_KEYMAP" "$ROOT/etc/vconsole.conf" &&
      ok "console keymap is $KB_CONSOLE_KEYMAP" || no "console keymap is not $KB_CONSOLE_KEYMAP"
    grep -qF "Option \"XkbLayout\" \"$KB_XKB_LAYOUT\"" "$ROOT/etc/X11/xorg.conf.d/00-keyboard.conf" &&
      ok "X11 layout is $KB_XKB_LAYOUT" || no "X11 layout is not $KB_XKB_LAYOUT"
    grep -qx "XKB_LAYOUT=$KB_XKB_LAYOUT" "$ROOT/etc/gnomarchy/keyboard.conf" &&
      ok "first-run will set input source $KB_XKB_LAYOUT" || no "keyboard.conf does not name $KB_XKB_LAYOUT"
  else
    no "GNOMARCHY_TEST_KEYMAP $GNOMARCHY_TEST_KEYMAP is not in keymaps.tsv"
  fi
fi
grep -q 'Installation complete' "$ROOT/var/log/gnomarchy-installer.log" &&
  ok "the installer log is on the target" || no "no complete installer log at /var/log/gnomarchy-installer.log"

if [[ "${GNOMARCHY_TEST_ENCRYPT:-n}" == y ]]; then
  luks_uuid="$(blkid -s UUID -o value "$GNOMARCHY_TEST_LUKS_DEV")"
  [[ -n "$luks_uuid" && " $cmdline " == *" rd.luks.name=$luks_uuid=cryptroot "* ]] &&
    ok "rd.luks.name opens the LUKS partition" || no "rd.luks.name does not name $luks_uuid" "$cmdline"
  if [[ -f "$ROOT/etc/crypttab" ]] && grep -q '^cryptroot' "$ROOT/etc/crypttab"; then
    no "crypttab also opens cryptroot" "the root is opened from the command line"
  else
    ok "crypttab does not compete with rd.luks.name"
  fi
  grep -qx 'AutomaticLoginEnable=true' "$ROOT/etc/gdm/custom.conf" &&
    ok "GDM autologin on the encrypted install" || no "GDM autologin not enabled on the encrypted install"
fi
```

The one `2>/dev/null` (reading `info.xml`) is a missing file, which the FAIL
branch already reports.

- [ ] **Step 2: Add the `unit` job to the workflow**

Under `jobs:`, before `install-test:`:

```yaml
  unit:
    name: Fast tests (boot menu, installer rules)
    runs-on: ubuntu-latest
    container: archlinux:latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install test dependencies
        run: pacman -Syu --noconfirm --needed kbd xkeyboard-config tzdata shellcheck diffutils

      - name: Run the fast tests
        run: bash iso/tests/unit.sh
```

Before writing it, confirm `shellcheck`, `kbd`, `xkeyboard-config`, `tzdata`
and `diffutils` exist with
`curl -sSL "https://archlinux.org/packages/search/json/?name=shellcheck"` (and
likewise for the others).

- [ ] **Step 3: Turn `install-test` into a two-variant matrix**

```yaml
  install-test:
    name: Install in QEMU and verify (${{ matrix.variant }})
    needs: unit
    runs-on: ubuntu-latest
    timeout-minutes: 200
    strategy:
      fail-fast: false
      matrix:
        variant: [plain, encrypted]
    env:
      ENCRYPT: ${{ matrix.variant == 'encrypted' && 'y' || 'n' }}
```

- `Install QEMU and image tooling`: add `cryptsetup-bin btrfs-progs` to `apt-get install`.
- `Create unattended answers disk`: replace the `echo 'GNOMARCHY_ENCRYPT=n'` line with:

```bash
            echo "GNOMARCHY_ENCRYPT=$ENCRYPT"
            # Each differs from its default, so a field the installer ignores
            # fails a check instead of passing by coincidence.
            echo 'GNOMARCHY_HOSTNAME=citest-host'
            echo 'GNOMARCHY_TIMEZONE=Europe/Berlin'
            echo 'GNOMARCHY_KEYMAP=de'
```

- `Mount the installed system`: replace the mount block with:

```bash
          ROOT_DEV=/dev/nbd0p3
          if [ "$ENCRYPT" = y ]; then
            printf '%s' ci-test-password-123 | sudo cryptsetup open --key-file=- /dev/nbd0p3 ci-root
            ROOT_DEV=/dev/mapper/ci-root
          fi
          echo "root_dev=$ROOT_DEV" >> "$GITHUB_OUTPUT"

          sudo mkdir -p /mnt/gnomarchy
          # The installer splits the filesystem into subvolumes. Mounting only
          # @ leaves /home, /var/log and /.snapshots as empty directories,
          # which silently turns every check against them into a false failure.
          if sudo mount -o subvol=@,ro "$ROOT_DEV" /mnt/gnomarchy; then
            sudo mount -o subvol=@home,ro "$ROOT_DEV" /mnt/gnomarchy/home
            sudo mount -o subvol=@var_log,ro "$ROOT_DEV" /mnt/gnomarchy/var/log
            sudo mount -o subvol=@snapshots,ro "$ROOT_DEV" /mnt/gnomarchy/.snapshots
            sudo mount -o ro /dev/nbd0p2 /mnt/gnomarchy/boot
            echo "mounted=true" >> "$GITHUB_OUTPUT"
            echo "--- root ---";       sudo ls /mnt/gnomarchy
            echo "--- home ---";       sudo ls /mnt/gnomarchy/home
            echo "--- var/log ---";    sudo ls /mnt/gnomarchy/var/log
            echo "--- .snapshots ---"; sudo ls /mnt/gnomarchy/.snapshots
          else
            echo "mounted=false" >> "$GITHUB_OUTPUT"
            echo "::error::Could not mount the installed root - the install never completed."
            exit 1
          fi
```

- `Show where the installer got to`: also print `sudo tail -40 /mnt/gnomarchy/var/log/gnomarchy-installer.log` when it exists.
- `Verify installed system (offline)`: env becomes

```yaml
        env:
          GNOMARCHY_TEST_USER: citest
          GNOMARCHY_TEST_DISK: /dev/nbd0
          GNOMARCHY_TEST_HOSTNAME: citest-host
          GNOMARCHY_TEST_TIMEZONE: Europe/Berlin
          GNOMARCHY_TEST_KEYMAP: de
          GNOMARCHY_TEST_ENCRYPT: ${{ env.ENCRYPT }}
          GNOMARCHY_TEST_LUKS_DEV: /dev/nbd0p3
```

- Every step after the offline verification that boots or prepares a boot (`Prepare the image for the session test`, `Boot the installed system…`, `Read session verification results`, and the screenshot steps) gets `&& matrix.variant == 'plain'` in its `if:`. Typing a passphrase into QEMU from CI is too brittle (spec, *Encrypted install*).
- Those steps replace `/dev/nbd0p3` with `${{ steps.mount.outputs.root_dev }}`.
- `Collect logs`: rewritten in Task 10 Step 5; leave it for now.
- `Upload logs`: `name: install-smoke-test-logs-${{ matrix.variant }}`.
- `Clean up`: add `sudo cryptsetup close ci-root 2>/dev/null || true  # only open on the encrypted variant`.

- [ ] **Step 4: Update CLAUDE.md's mount table**

In *Mounting the installed image* add the line
`/dev/nbd0p3  subvol=@snapshots  /.snapshots` and, after the table:
"On the encrypted variant the Btrfs is `/dev/mapper/ci-root`, opened from `/dev/nbd0p3` with the answers' password."

- [ ] **Step 5: Run the fast tests and lint the workflow**

Run: `bash iso/tests/unit.sh --deps`, then
`docker run --rm -v "$PWD:/w" -w /w rhysd/actionlint:latest -color` (if
Docker is available; otherwise rely on GitHub's parse in Task 12).
Expected: PASS; actionlint reports no errors in `install-smoke-test.yml`.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/install-smoke-test.yml iso/tests/verify-install.sh CLAUDE.md
git commit -m "test(ci): fast tests first, encrypted install, offline boot and snapshot checks"
```

---

### Task 10: CI — the session checks, the snapshot boot and the restore

**Files:**
- Modify: `iso/tests/verify-session.sh`, `.github/workflows/install-smoke-test.yml`

**Interfaces:**
- Reports move to `$HOME/.local/state/gnomarchy/verify/session.txt` (second boot) and `…/snapshot.txt` (third boot). The session report carries `SNAPSHOT: <N>`.
- The second boot ends with `gnomarchy-boot update --default snapshot:<N>`; the third boot ends with `gnomarchy snapshot restore <N> --yes`.

- [ ] **Step 1: Restructure the top of `iso/tests/verify-session.sh`**

Replace the header comment's report path and the `exec >"/var/tmp/…"` line with:

```bash
# Writes its report to ~/.local/state/gnomarchy/verify/<mode>.txt and powers
# off, so CI reads the outcome from the disk image rather than the serial
# console. /home is its own subvolume: the report survives a snapshot boot,
# whose root is a tmpfs overlay that /var/tmp used to vanish with.
MODE=session
SNAPSHOT_BOOTED=""
read -ra cmdline_words </proc/cmdline
for word in "${cmdline_words[@]}"; do
  [[ "$word" == gnomarchy.snapshot=* ]] && SNAPSHOT_BOOTED="${word#*=}"
done
[[ -n "$SNAPSHOT_BOOTED" ]] && MODE=snapshot
REPORT_DIR="$HOME/.local/state/gnomarchy/verify"
mkdir -p "$REPORT_DIR"
exec >"$REPORT_DIR/$MODE.txt" 2>&1
```

Move the closing block (from `echo` / `echo "=== $pass passed…"` through the
power-off) into a function defined right after `no()`:

```bash
finish() {
  echo
  echo "=== $pass passed, $fail failed ==="
  echo "RESULT: $([[ $fail -eq 0 ]] && echo SUCCESS || echo FAILURE)"
  sync
  trace "verification finished ($MODE): $pass passed, $fail failed"
  # Powering off ends the CI run. Go through sudo, which has an explicit
  # NOPASSWD rule: a bare systemctl poweroff depends on polkit granting it, and
  # if that is refused the script hangs and the whole job times out.
  sudo -n systemctl poweroff 2>/dev/null ||
    systemctl poweroff 2>/dev/null ||
    sudo -n reboot 2>/dev/null ||
    trace "could not power off"
  exit 0
}
```

and end the file with `finish`.

- [ ] **Step 2: Add the snapshot-boot branch**

Right after the first-run completion check, insert:

```bash
# --- Third boot: running from a snapshot ------------------------------------
if [[ "$MODE" == snapshot ]]; then
  n="$SNAPSHOT_BOOTED"
  echo "booted from snapshot $n"
  ok "a GNOME session came up from snapshot $n"
  [[ "$(findmnt -no FSTYPE /)" == overlay ]] && ok "/ is an overlay" ||
    no "/ is not an overlay" "$(findmnt -no FSTYPE,SOURCE,OPTIONS /)"
  [[ " ${cmdline_words[*]} " == *" rootflags=subvol=@snapshots/$n/snapshot "* ]] &&
    ok "the root is snapshot $n" || no "the command line does not point at snapshot $n"
  if echo probe >/var/tmp/gnomarchy-overlay-probe; then
    ok "the root accepts writes (CI checks they never reach the snapshot)"
  else
    no "the snapshot root is not writable"
  fi
  notified=0
  for _ in $(seq 1 30); do
    if journalctl --user -t gnomarchy-snapshot-notify --no-pager | grep -q "booted from snapshot $n"; then
      notified=1
      break
    fi
    sleep 1
  done
  ((notified)) && ok "the snapshot notice ran" || no "the snapshot notice never ran"
  echo "--- failed units (diagnostic only) ---"
  systemctl --failed --no-legend --no-pager
  if gnomarchy snapshot restore "$n" --yes; then
    ok "gnomarchy snapshot restore $n succeeded"
  else
    no "gnomarchy snapshot restore $n failed"
  fi
  grep -qx 'default_entry: Gnomarchy/linux' /boot/limine.conf &&
    ok "the menu defaults to linux again" || no "the menu does not default to linux after the restore"
  finish
fi
```

- [ ] **Step 3: Add the second-boot checks**

Before the control-center section, insert:

```bash
# --- Boot menu: snapshots, snap-pac and the theme ---------------------------
BOOT_BIN=/usr/local/lib/gnomarchy/boot/gnomarchy-boot
LIMINE=/boot/limine.conf

limine_refs_ok() {
  local path hash bad=0
  while read -r path hash; do
    if [[ ! -f "/boot$path" || "$(b2sum "/boot$path" | cut -d' ' -f1)" != "$hash" ]]; then
      echo "      bad reference: $path"
      bad=1
    fi
  done < <(sed -nE 's/^[[:space:]]*(kernel_path|module_path): boot\(\):([^#]+)#([0-9a-f]+)$/\2 \3/p' "$LIMINE")
  return "$bad"
}

snap="$(sudo -n snapper -c root create --print-number --description 'CI session snapshot')"
if [[ "$snap" =~ ^[0-9]+$ ]] && grep -q "^///$snap | " "$LIMINE"; then
  ok "snapshot $snap, made through snapperd, is in the boot menu"
else
  no "a snapshot made through snapperd did not reach the boot menu" "snapper printed: $snap"
fi
limine_refs_ok && ok "every boot file in limine.conf matches its hash" || no "limine.conf has stale references"

pkg="$(find /var/cache/pacman/pkg -name 'file-[0-9]*.pkg.tar.zst' | sort | tail -n1)"
if [[ -n "$pkg" ]] && sudo -n pacman -U --noconfirm "$pkg"; then
  post="$(sudo -n snapper --csvout --no-headers -c root list --columns number,type |
    awk -F, '$2 == "post" { n = $1 } END { print n }')"
  if [[ -n "$post" ]] && ((post > snap)) && grep -q "^///$post | " "$LIMINE"; then
    ok "snap-pac's post snapshot $post of a pacman transaction is in the boot menu"
  else
    no "no post snapshot of the pacman transaction in the boot menu" "newest post: ${post:-none}"
  fi
else
  no "could not reinstall the file package from the cache" "${pkg:-no package found}"
fi

# shellcheck source=../../default/boot/lib/palette.sh
source "$HOME/.local/share/gnomarchy/default/boot/lib/palette.sh"
want="$(boot_palette_from_alacritty "$HOME/.local/share/gnomarchy/themes/gruvbox/alacritty.toml" |
  sed -n 's/^BACKGROUND=//p')"
gnomarchy-theme-set gruvbox >/dev/null
recoloured=0
for _ in $(seq 1 20); do
  grep -qx "term_background: 00$want" "$LIMINE" && { recoloured=1; break; }
  sleep 1
done
((recoloured)) && ok "a theme change recolours the Limine menu" ||
  no "the Limine menu kept its colours after a theme change" "$(grep '^term_background' "$LIMINE")"
gnomarchy-theme-set tokyo-night >/dev/null

sources="$(gsettings get org.gnome.desktop.input-sources sources)"
[[ "$sources" == "[('xkb', 'de')]" ]] && ok "GNOME input sources are the installer's layout" ||
  no "GNOME input sources are not [('xkb', 'de')]" "$sources"
tz="$(timedatectl show -p Timezone --value)"
[[ "$tz" == Europe/Berlin ]] && ok "the timezone is Europe/Berlin" || no "the timezone is $tz"
```

and immediately before the final `finish`:

```bash
# Hand over to the third boot: the snapshot made above, which, unlike
# snapshot 1, includes CI's autologin and this script.
if [[ "$snap" =~ ^[0-9]+$ ]] && sudo -n "$BOOT_BIN" update --default "snapshot:$snap" &&
  grep -q "^default_entry: Gnomarchy/Snapshots/$snap | " "$LIMINE"; then
  ok "the next boot defaults to snapshot $snap"
  echo "SNAPSHOT: $snap"
else
  no "could not make snapshot $snap the next boot's default"
fi
```

- [ ] **Step 4: Prepare the second boot for all this in the workflow**

In `Prepare the image for the session test`:

- replace the sudoers line with:

```bash
          echo 'citest ALL=(ALL) NOPASSWD: /usr/bin/systemctl poweroff, /usr/bin/snapper, /usr/bin/pacman, /usr/local/lib/gnomarchy/boot/gnomarchy-boot' \
            | sudo tee /mnt/gnomarchy/etc/sudoers.d/99-ci-verify > /dev/null
```

- extend the serial-console edit to the base command line, so every menu the
  session regenerates keeps it:

```bash
            sudo sed -i 's/quiet splash/console=tty0 console=ttyS0,115200 systemd.log_level=info/' \
              /mnt/gnomarchy/boot/limine.conf /mnt/gnomarchy/etc/kernel/cmdline
```

In `Read session verification results`, set
`REPORT=/mnt/gnomarchy/home/citest/.local/state/gnomarchy/verify/session.txt`,
give the step `id: session`, and after the SUCCESS check add:

```bash
            SNAP="$(sudo sed -n 's/^SNAPSHOT: //p' "$REPORT")"
            echo "snapshot=$SNAP" >> "$GITHUB_OUTPUT"
```

then unmount and disconnect at the end of the step:

```bash
          sudo umount -R /mnt/gnomarchy
          sudo qemu-nbd --disconnect /dev/nbd0
          sleep 3
```

- [ ] **Step 5: Add the third boot and the restore check**

After `Read session verification results`:

```yaml
      - name: Boot the snapshot and restore it
        if: always() && steps.session.outputs.snapshot != '' && matrix.variant == 'plain'
        run: |
          ACCEL="-accel tcg"
          MEM=4096
          if [ "${{ steps.kvm.outputs.available }}" = "true" ]; then
            ACCEL="-accel kvm -cpu host"
            MEM=8192
          fi
          set +e
          sudo timeout 15m qemu-system-x86_64 \
            $ACCEL -smp 4 -m $MEM \
            -drive if=pflash,format=raw,readonly=on,file=${{ steps.ovmf.outputs.code }} \
            -drive if=pflash,format=raw,file=./OVMF_VARS.fd \
            -drive file=disk.qcow2,if=virtio,format=qcow2 \
            -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
            -display none -serial file:snapshot-serial.log \
            -no-reboot
          echo "qemu exit: $?"
          set -e
          sudo chown "$USER:$USER" disk.qcow2 snapshot-serial.log

      - name: Read snapshot-boot results and check the restore
        if: always() && steps.session.outputs.snapshot != '' && matrix.variant == 'plain'
        env:
          SNAP: ${{ steps.session.outputs.snapshot }}
        run: |
          sudo qemu-nbd --connect=/dev/nbd0 disk.qcow2
          sleep 5
          ROOT_DEV=${{ steps.mount.outputs.root_dev }}
          sudo mount -o subvol=@home,ro "$ROOT_DEV" /mnt/gnomarchy
          REPORT=/mnt/gnomarchy/citest/.local/state/gnomarchy/verify/snapshot.txt
          if ! sudo test -f "$REPORT"; then
            echo "::error::No snapshot-boot report - snapshot $SNAP never reached a session."
            tail -150 snapshot-serial.log || true
            exit 1
          fi
          echo "=== snapshot-boot report ==="
          sudo cat "$REPORT"
          sudo umount /mnt/gnomarchy

          sudo mkdir -p /mnt/gnomarchy-top
          sudo mount -o subvolid=5,ro "$ROOT_DEV" /mnt/gnomarchy-top
          failed=0
          if compgen -G "/mnt/gnomarchy-top/@restore-backup-*" > /dev/null; then
            echo "PASS  the previous root is kept as $(cd /mnt/gnomarchy-top && ls -d @restore-backup-*)"
          else
            echo "FAIL  no @restore-backup-* after the restore"; failed=1
          fi
          parent="$(sudo btrfs subvolume show /mnt/gnomarchy-top/@ | awk '/Parent UUID:/ { print $3 }')"
          uuid="$(sudo btrfs subvolume show "/mnt/gnomarchy-top/@snapshots/$SNAP/snapshot" | awk '$1 == "UUID:" { print $2 }')"
          if [ -n "$uuid" ] && [ "$parent" = "$uuid" ]; then
            echo "PASS  @ is a copy of snapshot $SNAP"
          else
            echo "FAIL  @'s parent is '$parent', snapshot $SNAP is '$uuid'"; failed=1
          fi
          if sudo test -e "/mnt/gnomarchy-top/@snapshots/$SNAP/snapshot/var/tmp/gnomarchy-overlay-probe"; then
            echo "FAIL  a write during the snapshot boot reached the snapshot"; failed=1
          else
            echo "PASS  writes during the snapshot boot stayed in the overlay"
          fi
          sudo umount /mnt/gnomarchy-top
          if ! sudo grep -q "RESULT: SUCCESS" "$REPORT" || [ "$failed" -ne 0 ]; then
            echo "::error::Snapshot boot or restore failed."
            exit 1
          fi
```

`subvol=@home` is mounted at `/mnt/gnomarchy`, so the report is under
`/mnt/gnomarchy/citest/…`, not `/mnt/gnomarchy/home/citest/…`.

In `Collect logs`, replace the two `sudo cp /mnt/gnomarchy/var/...` lines with:

```bash
          cp snapshot-serial.log artifacts/ 2>/dev/null || true
          # Read the logs through mounts of their own: by now earlier steps
          # may have unmounted /mnt/gnomarchy. A failure here only means an
          # earlier step never got that far, which that step already reported.
          ROOT_DEV="${{ steps.mount.outputs.root_dev }}"
          if [ -n "$ROOT_DEV" ]; then
            sudo mkdir -p /mnt/ci-log /mnt/ci-home
            sudo mount -o subvol=@var_log,ro "$ROOT_DEV" /mnt/ci-log || true
            sudo mount -o subvol=@home,ro "$ROOT_DEV" /mnt/ci-home || true
            sudo cp /mnt/ci-log/gnomarchy-install.log /mnt/ci-log/gnomarchy-installer.log artifacts/ || true
            sudo cp /mnt/ci-home/citest/.local/state/gnomarchy/verify/*.txt artifacts/ || true
            sudo umount /mnt/ci-log /mnt/ci-home || true
          fi
```

and in `Clean up` add `sudo umount /mnt/ci-log /mnt/ci-home 2>/dev/null || true  # only mounted if Collect logs got that far`.

- [ ] **Step 6: Run the fast tests**

Run: `bash iso/tests/unit.sh --deps`
Expected: PASS, shellcheck clean.

- [ ] **Step 7: Commit**

```bash
git add iso/tests/verify-session.sh .github/workflows/install-smoke-test.yml
git commit -m "test(ci): snapshots through snapperd and snap-pac, theme, a snapshot boot and a restore"
```

---

### Task 11: Documentation

**Files:**
- Modify: `README.md`, `manual/14-snapshots.md`, `manual/02-getting-started.md`, `site/app.js`, `default/gnomarchy-skill/SKILL.md`, `.github/workflows/build-and-release.yml`, `TESTING.md`, `CLAUDE.md`

Every sentence must be backed by code from Tasks 1–10. Nothing about BIOS boots
or encrypted boots being tested in CI.

- [ ] **Step 1: README.md**

- Line 34 bullet:

```markdown
- **🛡️ Bootable Btrfs Snapshots**: Snapper takes a snapshot before and after every pacman transaction, and each one appears in the Limine boot menu. Boot one to try it — changes stay in memory — and `gnomarchy snapshot restore` makes it the system.
```

- Installation step 4:

```markdown
4. The installer starts on TTY1: pick a disk, fill in a short form (keyboard layout, user, password, computer name, timezone, optional LUKS2 encryption), check the summary and watch seven stages run. It lays out Btrfs subvolumes (`@`, `@home`, `@snapshots`, `@var_log`, `@var_cache`), installs Limine for both UEFI and BIOS, and takes a first snapshot.
```

- `### Rollback Snapshots` block:

```bash
# Create an atomic snapshot before doing risky work
gnomarchy snapshot create "Before system refactor"

# List snapshots
gnomarchy snapshot list

# Make a snapshot the system from the next boot on (asks which, without a number)
gnomarchy snapshot restore 12
```

- [ ] **Step 2: Rewrite `manual/14-snapshots.md`**

```markdown
# Snapshots and Rollback

The root filesystem is Btrfs with Snapper, and every snapshot appears in the
Limine boot menu under **Gnomarchy → Snapshots**.

```bash
gnomarchy snapshot create "Before trying something risky"
gnomarchy snapshot list
gnomarchy snapshot restore 12
```

## Automatic snapshots

`snap-pac` takes one before and one after every pacman transaction, so a
package update that goes wrong is already covered. There are no timeline
snapshots; Snapper keeps the last 10 numbered ones (5 marked important), and
snapshot 1, "Gnomarchy installed", is never cleaned up.

## Trying a snapshot

1. Reboot and open **Snapshots** in the Limine menu.
2. Pick one. Each entry boots the kernel that snapshot was taken with.
3. The system starts from the snapshot, read-only underneath and writable in
   memory: anything you change is gone at the next reboot. A notification says
   so and offers to restore it.

## Restoring

`gnomarchy snapshot restore <number>` makes a snapshot the system from the
next boot on. It works from the normal system and from a snapshot you booted.
The system you had is kept as `@restore-backup-<time>` until the next restore.

## Limits

- Snapshot kernels live on the 4 GiB EFI partition. When it is more than 80%
  full the oldest snapshots leave the menu; they stay on disk and can still be
  restored.
- A snapshot taken under a kernel that is no longer on the EFI partition has
  no menu entry.

## Subvolume layout

    @            root
    @home        home, deliberately not rolled back with the system
    @snapshots   the snapshots themselves
    @var_log     logs, kept across rollbacks
    @var_cache   package cache

`@home` being separate is the important part: rolling the system back does not
take your documents with it.

## Before risky work

Ask an AI agent to snapshot first, or do it yourself. It costs nothing - Btrfs
snapshots are copy-on-write and take no space until things diverge.
```

- [ ] **Step 3: Add an installer section to `manual/02-getting-started.md`**

Add at the top of the page body:

```markdown
## Installing

Boot the ISO; the installer starts on its own on the first console.

1. **Disk.** Choose the disk. All of it is used and erased; disks under
   20 GiB are refused.
2. **Form.** Keyboard layout first — the console switches to it, so the
   passwords that follow are typed the way you will type them later. Then
   your name, user name, password, the computer's name and the timezone (type
   to search). Encryption is optional; the disk password can be the same as
   your own.
3. **Summary.** Check it. *Edit* goes back to the form with your answers
   kept; nothing is written until you choose *Install*.
4. **Progress.** Seven stages. If one fails, the screen shows the end of the
   log and offers the full log, a shell, or power off. The log is
   `/var/log/gnomarchy-installer.log`, copied to the installed system.
```

- [ ] **Step 4: site/app.js, SKILL.md, release notes, TESTING.md**

- `site/app.js` snapshot `note`:

```js
      note: 'Snapper snapshots the root before and after every pacman transaction. ' +
            'Each snapshot appears in the Limine menu and boots with its own kernel; ' +
            'gnomarchy snapshot restore makes one the system. /home is a separate ' +
            'subvolume and is not part of a root snapshot.'
```

- `default/gnomarchy-skill/SKILL.md`: line 31 →
  "Every snapshot appears in the Limine menu, and `gnomarchy snapshot restore <n>` makes one the system."
  In section 8 add:

```bash
# Make snapshot 12 the system from the next boot on
gnomarchy snapshot restore 12 --yes
```

- `.github/workflows/build-and-release.yml:99` →
  `- **Bootable Btrfs snapshots**: every snapshot is in the Limine menu and can be restored with \`gnomarchy snapshot restore\`.`
- `TESTING.md`:
  - Replace "Verify snapshot appears in Snapper and Limine boot menu upon reboot." with
    "Reboot: the snapshot is under Gnomarchy → Snapshots in the Limine menu. Boot it, confirm the 'Booted snapshot' notification, then run `gnomarchy snapshot restore <n>` and reboot."
  - In the manual installer checklist, replace the disk-prompt bullet with
    "Choose `/dev/vda` in the disk list, fill the form, check the summary, watch the seven stages."
  - In the CI description, list the new layers: the `unit` job (boot menu generator, snapper plugin, deploy, installer rules, shellcheck), the encrypted variant (offline only), the snapshot checks in the session boot, and the third boot from a snapshot ending in a restore. Add a *Not covered by CI* list: booting in BIOS mode (offline: `limine-bios.sys` and the MBR boot code), an encrypted boot (no passphrase entry), the gum screens.
  - Update the answers example with `GNOMARCHY_HOSTNAME`, `GNOMARCHY_TIMEZONE`, `GNOMARCHY_KEYMAP` and `GNOMARCHY_DISK_PASSWORD` (optional).

- [ ] **Step 5: CLAUDE.md**

- Layout block: replace the `login/` line with `login/  GDM, Plymouth, the Limine menu (boot.sh)`; add `default/boot/  gnomarchy-boot, snapper plugin, pacman hooks, initramfs hook (deployed root-owned)` and `iso/installer/  the installer (gnomarchy-install + lib/)`; change the `.automated_script.sh` line to `…/.automated_script.sh   starts iso/installer/gnomarchy-install on tty1`.
- *The theme engine*: add `/etc/gnomarchy/boot-theme.conf` to the list of
  files only `gnomarchy-theme-set` writes.
- New section after *The theme engine*:

```markdown
## The bootloader and snapshots

`gnomarchy-boot` is the only thing that writes `/boot/limine.conf`. It
regenerates the whole file from `/etc/kernel/cmdline`, the kernels on the ESP,
per-snapshot records in `/boot/gnomarchy/entries/` and the theme in
`/etc/gnomarchy/boot-theme.conf`. Change the command line in
`/etc/kernel/cmdline`, never in `limine.conf`.

It runs as root from `/usr/local/lib/gnomarchy/boot/`, copied there by
`default/boot/deploy.sh` (installer, `install.sh`, `gnomarchy update`). Root
never executes scripts from a user's home.

Snapshot kernels are content-addressed in `/boot/gnomarchy/store/`; a
snapshot boots read-only under `systemd.volatile=overlay`, which needs the
`gnomarchy-overlay` initcpio hook. fstab must not contain `subvolid=`.

`gnomarchy-boot`'s fast tests run its real code against a fake tree through
`GNOMARCHY_BOOT_ROOT`: `iso/tests/unit.sh`, in an archlinux container.
```

- *Verification*: add the `unit` job, the encrypted variant, and that session
  reports are under `~/.local/state/gnomarchy/verify/` (`session.txt`,
  `snapshot.txt`) because a snapshot boot's `/var/tmp` is volatile.
- *Diagnosing a failure*: add
  `/var/log/gnomarchy-installer.log   the installer's own log; the [n/7] lines show the stage`
  and `/var/log/pacman.log   gnomarchy-boot output from the pacman hooks`.

- [ ] **Step 6: Check that no old claim survives**

Run: `git grep -n -i "limine does not currently\|snapper rollback\|timeline and cleanup" -- . ':!docs/superpowers'`
Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add README.md manual/14-snapshots.md manual/02-getting-started.md site/app.js \
  default/gnomarchy-skill/SKILL.md .github/workflows/build-and-release.yml TESTING.md CLAUDE.md
git commit -m "docs: the installer, bootable snapshots and how CI proves them"
```

---

### Task 12: Push and get the smoke test green

**Files:** whatever the failures point at.

- [ ] **Step 1: Run the fast tests one last time**

Run: `bash iso/tests/unit.sh --deps`
Expected: all PASS.

- [ ] **Step 2: Push the branch and start the smoke test**

```bash
git push -u origin feat/installer-limine
gh workflow run install-smoke-test.yml --ref feat/installer-limine
gh run list --workflow install-smoke-test.yml --branch feat/installer-limine --limit 1
```

`workflow_dispatch` runs the branch's own version of the workflow. Do not open
a pull request unless the user asks for one.

- [ ] **Step 3: Read the result when the run finishes**

`gh run watch <run-id> --exit-status` in the background; when it ends,
`gh run view <run-id> --log-failed`, and download the artifacts
(`gh run download <run-id>`) for the installer log, serial logs and reports.

- [ ] **Step 4: Fix and repeat**

For each failure, use superpowers:systematic-debugging: read the log, form one
hypothesis, change one thing, commit with a message naming the defect, push,
re-run. Likely first-run problems and where to look:

| Symptom | Look at |
|---|---|
| installer powers off early | `installer-serial.log`, then the copied `gnomarchy-installer.log` |
| `mkinitcpio -P` fails | a HOOKS entry without its package; `gnomarchy-overlay`'s `add_systemd_unit` |
| no `limine.conf` hash matches | a pacman hook racing the menu; `/var/log/pacman.log` on the image |
| snapshot boot never reaches GDM | `snapshot-serial.log`; `systemd-remount-fs` on the overlay root (spec, *Risks*) |
| restore fails | `btrfs subvolume list -o` output; the nested-subvolume deletion |

- [ ] **Step 5: Done when**

Both matrix entries and the `unit` job are green on the same commit. Report
the run URL and the commit.
