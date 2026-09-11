# Offline Gnomarchy ISO

An experimental second ISO that installs a complete Gnomarchy system with no
network connection, published as a CI artifact alongside — never instead of —
the ISO that ships today.

Status: design approved, not yet implemented.
Branch: `experiment/offline-iso`.

## Why

Today an install fetches from eight separate places. Six of them are hard
dependencies: without a network, `pacstrap` never completes and the machine is
left with a partitioned disk and nothing on it.

| Step | Fetches |
|---|---|
| `.automated_script.sh`, `pacstrap -K` | base system from Arch mirrors |
| `install/preflight/pacman.sh` | `pacman -Sy` database refresh |
| `install/packaging/base.sh` | the 135 packages in `gnomarchy-base.packages` |
| `install/packaging/tools.sh` | PyPI (`gext` via pipx), `mise.run`, the paru release tarball |
| `install/packaging/brave-origin.sh` | the Brave Origin GitHub release |
| `install/packaging/flatpak.sh`, `.automated_script.sh` | Flathub (Bazaar, LocalSend) |
| `install/config/theme.sh` → `gnomarchy-backgrounds` | Omarchy wallpapers |
| `install/config/repository.sh` | the git remote |

GNOME extensions are already bundled in `default/gnome/extensions/` and need no
work. Wallpapers already degrade to the generated SVG in each theme.

## Scope

**In.** Every pacman package, the Brave Origin binary, paru and mise ship on
the ISO. An install completes with the NIC unplugged, and CI proves it by
installing in QEMU with `-nic none`.

**Deferred to first boot.** Flatpaks (Bazaar, LocalSend) and the Omarchy
wallpapers. `/usr/local/bin/gnomarchy-firstboot` already exists, already waits
for connectivity and is already idempotent; an offline install simply leaves it
with work to do. `gnomarchy-backgrounds` already falls back to the bundled SVGs.

**Out.** No Flatpak bundling, no wallpaper redistribution (see `BACKGROUNDS.md`
— the licensing reason not to commit them applies just as much to shipping them
in an ISO), no AUR, no release-workflow changes, and no change whatsoever to
the behaviour of the online ISO.

## Approach

A local pacman repository baked into the ISO.

A build-time step resolves the full dependency closure into a directory of
`.pkg.tar.zst` files with their `.sig` files intact, runs `repo-add` over it,
and ships the result in the airootfs. The installer adds one
`[gnomarchy-offline]` stanza pointing at that directory over `file://`.

Two alternatives were considered and rejected:

- **Pre-seeded cache plus snapshotted sync databases** — drop packages into
  `/var/cache/pacman/pkg` and the real `core.db`/`extra.db` alongside them.
  Installed packages keep their true repo origin, but cache and database must
  be byte-consistent or pacman silently falls back to a mirror, and an
  incomplete closure surfaces at install time rather than build time.
- **Image-based install** — build the finished system once, squashfs it,
  unsquash it onto the Btrfs subvolume. Fastest install, but it bypasses the
  entire `install/` stage architecture and would be a rewrite.

The local repo wins on two specific points. Package signatures survive, so the
target keeps `SigLevel = Required DatabaseOptional` rather than `TrustAll`. And
`install/packaging/base.sh` pre-validates its list against `pacman -Slq`, which
a local repo populates exactly like any other — that logic keeps working
untouched.

## Components

### 1. `iso/builder/build-offline-repo.sh` (new)

Produces a directory containing every package the install needs, plus a repo
database.

```bash
pacman -Syw --config iso/configs/pacman-online-stable.conf \
  --root "$EMPTY" --dbpath "$EMPTY/var/lib/pacman" \
  --cachedir "$REPO" --noconfirm  <closure>
repo-add "$REPO/gnomarchy-offline.db.tar.zst" "$REPO"/*.pkg.tar.zst
```

**The empty root is load-bearing.** In the Arch build container `base`,
`base-devel` and `glibc` are already installed, and `pacman -Sw` skips
dependencies it considers satisfied. Resolving the closure against the
container's own database would produce an ISO missing precisely the packages
nobody would think to check, and the failure would not appear until an offline
`pacstrap` died on a machine with no way to recover.

The closure is the union of:

- the `pacstrap` set from `.automated_script.sh`: `base base-devel linux
  linux-firmware btrfs-progs sudo git curl neovim networkmanager limine`
- every entry in `install/gnomarchy-base.packages`
- every entry in `install/gnomarchy-hardware.packages` (new — see below)
- `archlinux-keyring`

The script fails loudly if `pacman -Syw` reports any package as unresolvable.
Unlike `base.sh` at install time, a missing name here is a build defect and
must stop the build rather than warn.

### 2. `install/gnomarchy-hardware.packages` (new)

`install/config/hardware/` installs packages conditionally on detected
hardware: `asusctl` and `rog-control-center` in `asus.sh`,
`intel-media-driver` and `vulkan-intel` in `intel/video-acceleration.sh`. Both
call sites already tolerate failure, so an offline install without them merely
degrades — but since they are official-repo packages, bundling them is nearly
free and makes the offline install match the online one on the hardware that
needs them.

The file lists those four names. `build-offline-repo.sh` folds it into the
closure. `install/config/hardware/*` is not otherwise changed.

### 3. `iso/builder/build-iso.sh` (modified)

Gains an `--offline` flag. When set:

- calls `build-offline-repo.sh`, writing directly into
  `$PROFILE_DIR/airootfs/var/cache/gnomarchy-offline-repo/` so the 5 GB payload
  is never copied twice
- stages the non-pacman payloads (below) into
  `$PROFILE_DIR/airootfs/var/cache/gnomarchy-offline-payloads/`
- rewrites two lines in the *staged* copy of `profiledef.sh`, leaving the
  in-repo file untouched: `airootfs_image_tool_options` becomes `-comp zstd
  -Xcompression-level 3`, and `iso_name` becomes `gnomarchy-linux-offline` so
  the two ISOs cannot be confused on disk or in an artifact listing

The compression override matters: squashfs at level 15 over ~5 GB of
already-zstd-compressed packages buys almost nothing and costs roughly half an
hour of build time. Everything else about the profile — bootmodes, file
permissions, the repo rsync, the wallpaper staging — is shared, so the two ISOs
cannot drift apart.

Without `--offline` the script behaves exactly as it does today.

### 4. Bundled non-pacman payloads

Staged into `airootfs/var/cache/gnomarchy-offline-payloads/`:

| Payload | Consumed by |
|---|---|
| Brave Origin release tarball | `install/packaging/install-brave.py` |
| paru `x86_64` release tarball | `install/packaging/tools.sh` |
| mise binary | `install/packaging/tools.sh` |

`gext` (PyPI, via pipx) is **not** bundled. It manages GNOME extensions, and
extensions already come from `default/gnome/extensions/`, so it has nothing to
do on a fresh offline install. `tools.sh` skips it with an explicit warning
rather than silently.

### 5. `iso/configs/pacman-offline.conf` (new)

The pacman configuration used for `pacstrap` and inside the chroot. `[core]`,
`[extra]` and `[multilib]` are absent; the only repository is:

```
[gnomarchy-offline]
SigLevel = Required DatabaseOptional
Server = file:///var/cache/gnomarchy-offline-repo
```

`Required` keeps per-package signature verification; `DatabaseOptional`
accommodates the unsigned database `repo-add` produces.

### 6. `iso/configs/airootfs/root/.automated_script.sh` (modified)

Detects `/var/cache/gnomarchy-offline-repo/gnomarchy-offline.db`. When present:

- sets and exports `GNOMARCHY_OFFLINE=1`
- runs `pacstrap -C /etc/pacman-offline.conf -K /mnt …` with the existing
  package set
- **bind-mounts** the repo into `/mnt/var/cache/gnomarchy-offline-repo`.
  `arch-chroot` cannot see the live filesystem, and copying the directory would
  write 5 GB to the target disk only to delete it minutes later. The bind mount
  is registered with the existing `trap` so it is released on failure as well
  as success.
- inserts the `[gnomarchy-offline]` stanza into `/mnt/etc/pacman.conf` *above*
  `[core]`, so it takes precedence for the rest of the install. The target's
  `pacman.conf` is the stock one shipped by the `pacman` package; `[core]` and
  `[extra]` remain listed but have no synced database, which is harmless as
  long as the offline repo satisfies every request. `install/packaging/base.sh`
  needs no change: `pacman -Slq` reads whatever local sync databases exist, and
  offline that is the `gnomarchy-offline` database alone.
- passes `GNOMARCHY_OFFLINE=1` through the `arch-chroot -u "$USERNAME"`
  invocation alongside `GNOMARCHY_CHROOT_INSTALL=1`
- skips the Flatpak preinstall block entirely, leaving it to first boot

When the repo is absent the script takes exactly its current path, so the
online ISO is unaffected.

### 7. Install stages that assume a network (modified)

| File | Change |
|---|---|
| `install/preflight/pacman.sh` | `sudo pacman -Sy --noconfirm` is unguarded under `set -e` and will abort the install offline. Skip it when `GNOMARCHY_OFFLINE=1`; the local database is already current. |
| `install/packaging/tools.sh` | Prefer the bundled paru and mise payloads; skip `gext` with a warning when offline. |
| `install/packaging/brave-origin.sh`, `install-brave.py` | Accept a local tarball path; `install-brave.py` takes it from the payload directory when `GNOMARCHY_OFFLINE=1` instead of querying GitHub. |
| `install/packaging/flatpak.sh` | Already skips installs under `GNOMARCHY_CHROOT_INSTALL`. Confirm `flatpak remote-add` is harmless offline; guard it if not. |
| `install/post-install/pacman.sh` | Strip the `[gnomarchy-offline]` stanza from the target's `/etc/pacman.conf`. A `file://` repo pointing at a path that vanishes on reboot would break the first `gnomarchy update`. |

`install/config/theme.sh` and `bin/gnomarchy-backgrounds` need no change — the
SVG fallback path already exists and is exercised whenever a download fails.
The implementation must confirm this rather than assume it.

### 8. `.github/workflows/offline-iso.yml` (new)

Modelled on `install-smoke-test.yml`, with four differences:

1. Builds with `--offline`.
2. **Every working directory lives under `/mnt`.** `ubuntu-latest` has roughly
   14 GB free on `/` even after the existing cleanup step, and about 65 GB on
   `/mnt`, the ephemeral temp disk. Peak build usage is an estimated 20–25 GB
   (repo, profile, mkarchiso work dir, squashfs, ISO), so `/` is not an option.
3. QEMU runs with `-nic none` in place of the user-mode netdev. This is the
   entire point of the job: an install that only passes with a network proves
   nothing.
4. Uploads the ISO with `actions/upload-artifact`. No release step, no
   checksum-splitting, no change to `build-and-release.yml`.

Triggered by `workflow_dispatch` and by pushes to `experiment/offline-iso`, so
it never competes with the main smoke test for runner time.

### 9. Verification

`iso/tests/verify-install.sh` and `iso/tests/verify-session.sh` run unchanged
against the offline-installed image — the resulting system should be
indistinguishable from an online install apart from the deferred Flatpaks and
wallpapers.

Four checks are added, in the spirit of the existing suite where every check
corresponds to a defect that once shipped:

1. **`[gnomarchy-offline]` is gone from the installed `/etc/pacman.conf`.** A
   leftover stanza breaks the first `gnomarchy update`.
2. **A Brave binary is present and executable.** The `Super`-key browser
   binding in `set-gnome-hotkeys.sh` launches it; its absence is user-visible
   on the first keystroke. A previous release shipped Brave non-executable.
3. **The install log contains every `STAGE OK` marker.** An offline install
   that silently skipped a stage would otherwise pass every other check.
4. **The install log contains no network-failure text.** Catches a fetch that
   was hidden behind `|| true` and degraded quietly rather than being bundled.

These go in `verify-install.sh` behind a `GNOMARCHY_EXPECT_OFFLINE` guard so
the online smoke test is unaffected.

## Trade-offs and risks

**The repo is a snapshot.** A machine installed from the offline ISO is out of
date the moment it boots. `gnomarchy update` resolves this on first network
contact. This is inherent to offline installation, not a defect to fix.

**Runner disk space.** The `/mnt` placement should be sufficient with room to
spare, but the estimate is exactly that. If a build runs out of space, the
fallback is trimming the heavy optionals — `code`, `discord`,
`telegram-desktop`, `qemu-desktop`, `jdk-openjdk`, `whisper-cpp`,
`noto-fonts-cjk` — from the offline closure only, leaving
`gnomarchy-base.packages` untouched for online installs.

**Build and test duration.** Downloading ~5 GB and squashing it, then a full
QEMU install, will run long. The existing smoke test already allows 200
minutes; the offline job should allow the same or more.

**ISO size.** An estimated 5–6.5 GB against roughly 1.2 GB today. GitHub
release assets are capped at 2 GB each, which is why this is a CI artifact.
Public distribution is a separate decision, deliberately not made here.

## Migrations

None. Nothing in this design alters the configuration of a machine that is
already installed — the changes are confined to the ISO build, the installer,
and network-conditional branches that behave identically when
`GNOMARCHY_OFFLINE` is unset.

## Documentation

`README.md`, `AGENTS.md` and `CLAUDE.md` describe a single ISO. Once this works,
each needs a paragraph on the offline variant: what it contains, what it defers
to first boot, and that it is a CI artifact rather than a release download.
Per the repository's standing rule, those edits land in the same commit as the
behaviour they describe.
