# Gnomarchy Verification & Testing Guide

This guide details the procedure for testing Gnomarchy scripts, the live ISO build, and the installed GNOME environment.

---

## 0. Automated Install Smoke Test (CI)

`.github/workflows/install-smoke-test.yml` builds the ISO, **installs from it in
QEMU**, and verifies the result. It runs on pushes to `main`, on pull requests
touching `iso/`, `install/`, `bin/` or `default/`, and on demand via
`workflow_dispatch`.

This exists because the release workflow only proves the ISO *builds*. Every
installation defect so far shipped through a green build: a package name that
aborted pacman, keyboard shortcuts silently discarded in a chroot, duplicate
dock entries, a deployed tree with no `.git`, helper commands missing from the
session PATH, and a wallpaper path pointing at a layout that no longer existed.

The installer is driven by an answers file on a separate disk labeled
`GNOMARCHY`, so **the ISO under test is byte for byte the ISO that ships**.
To reproduce locally:

```bash
printf '%s
'   'GNOMARCHY_DISK=/dev/vda'   'GNOMARCHY_FULLNAME="Test User"'   'GNOMARCHY_USERNAME=citest'   'GNOMARCHY_PASSWORD=test-password'   'GNOMARCHY_ENCRYPT=n' > gnomarchy-unattended.conf

truncate -s 8M answers.img
mkfs.vfat -n GNOMARCHY answers.img
mcopy -i answers.img gnomarchy-unattended.conf ::/
```

Attach `answers.img` as a second drive and the installer runs without prompts.

The job checks two layers:

- **Offline** (`iso/tests/verify-install.sh`, run against the mounted image):
  GDM enabled, whisper backend installed, every `gnomarchy-*` command in
  `/usr/local/bin`, a real git checkout, per-theme wallpaper layout with the
  upstream images downloaded, exactly one visible Brave entry, an autostart
  entry with an absolute `Exec`, and the Alacritty/btop/LazyVim configs.
- **In session** (`iso/tests/verify-session.sh`, run inside a real autologin
  session): `gnomarchy-first-run` completed, the custom keybindings are in
  dconf, `Super+W` and `Super+1` work, the dock is on the left, exactly one
  Brave in favorites, the wallpaper is not the SVG placeholder, and GNOME
  Terminal carries a full 16-colour palette.

Cut a release only from a commit where this job is green.

---

## 1. Syntax & Static Analysis Verification

To ensure all bash scripts and package manifests are syntactically sound:

```bash
# Verify syntax of all shell scripts
find . -type f -name "*.sh" -exec bash -n {} +
find bin/ -type f -exec bash -n {} +

# Optional: Run shellcheck if installed
shellcheck boot.sh install.sh bin/* install/**/*.sh
```

---

## 2. Virtual Machine Testing (QEMU / KVM)

### Prerequisites
Install QEMU, KVM, and OVMF UEFI firmware:
```bash
# Arch Linux host
sudo pacman -S qemu-desktop edk2-ovmf virt-manager

# Ubuntu/Debian host
sudo apt install qemu-system-x86 ovmf
```

### Steps:
1. **Build the Live ISO**:
   ```bash
   sudo ./iso/builder/build-iso.sh
   ```
2. **Launch QEMU with UEFI Boot**:
   ```bash
   ./run-vm.sh out/gnomarchy-linux-*.iso
   ```
3. **Verify Installer Workflow**:
   - Confirm Tokyo Night colors display on TTY1.
   - Verify disk selection prompt identifies the virtual drive (`/dev/vda`).
   - Test both unencrypted and encrypted (LUKS) installation paths.
   - Observe Btrfs subvolume creation (`@`, `@home`, `@snapshots`, `@var_log`, `@var_cache`).
   - Observe package installation and chroot execution of `install.sh`.
4. **Reboot into Installed System**:
   - Reboot the VM without the `-cdrom` flag:
     ```bash
     ./run-vm.sh
     ```
   - Verify GDM starts and logs into the GNOME Wayland session.

---

## 3. Desktop Environment & Functional Verification

Once logged into the Gnomarchy desktop:

1. **Test Tactile Tiling**:
   - Press <kbd>Super</kbd> + <kbd>T</kbd>.
   - Confirm the tiling grid overlay appears.
   - Press a quadrant/zone key and verify the window snaps to that zone with proper gaps.
2. **Test Keybindings**:
   - <kbd>Super</kbd> + <kbd>Return</kbd>: Launches GNOME Terminal in the Gnomarchy
     profile (JetBrains Mono 10, no scrollbar, 110x30).
   - <kbd>Super</kbd> + <kbd>1</kbd>–<kbd>6</kbd>: Switches workspaces.
   - <kbd>Super</kbd> + <kbd>W</kbd>: Closes active window.
3. **Test the Command Center**:
   - Press <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>Space</kbd>.
   - Confirm a floating Alacritty window opens with the gum menu.
   - Walk into Theme, pick a theme with the filter, and confirm it applies.
   - Confirm `Exit` and <kbd>Esc</kbd> both close the menu cleanly.
4. **Test Screen Capture**:
   - <kbd>Ctrl</kbd> + <kbd>Print</kbd>: confirm a slurp region selector appears,
     then that Satty opens with the grab.
   - Cancel a selection with <kbd>Esc</kbd> and confirm no error notification.
   - `gnomarchy capture screen` writes into `~/Pictures/Screenshots/`.
5. **Test Theme Engine**:
   - Open a terminal and run:
     ```bash
     gnomarchy theme list
     gnomarchy theme set catppuccin
     gnomarchy theme set gruvbox
     gnomarchy theme set tokyo-night
     ```
   - Verify that:
     - GNOME wallpaper changes immediately.
     - GNOME accent color updates (e.g. Purple for Catppuccin, Orange for Gruvbox, Blue for Tokyo Night).
     - A running GNOME Terminal repaints: background, foreground and all 16 ANSI
       colors (check with `gsettings get        "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/" palette`).
     - Alacritty window background and foreground update (in a *running* window;
       the base config at `~/.config/alacritty/alacritty.toml` must show
       JetBrains Mono at 10pt with 14px padding).
     - `btop` opens in the new palette (verify `color_theme = "current"` in
       `~/.config/btop/btop.conf`).
     - Neovim theme updates on launch, and
       `~/.config/nvim/lua/plugins/gnomarchy-colorscheme.lua` names the new scheme.
     - GTK apps follow: `~/.config/gtk-4.0/gnomarchy-theme.css` is regenerated and
       `gtk.css` imports it exactly once (re-run the theme set twice and confirm
       the import is not duplicated).
6. **Test Voxtype**:
   - `which whisper-cli` resolves, and `systemctl is-enabled ydotoold` reports enabled.
   - Press <kbd>Super</kbd> + <kbd>D</kbd>, speak, press again; confirm the text is
     typed into the focused window (a re-login may be needed for the `input` group).
7. **Test Backgrounds**:
   ```bash
   gnomarchy backgrounds --list     # 92/92 installed after a networked install
   gnomarchy backgrounds --verify   # every file matches the pinned manifest
   ```
   - Confirm `/usr/share/backgrounds/gnomarchy/<theme>/` holds per-theme folders.
   - Corrupt a file (`sudo truncate -s -1 <file>`), re-run `--verify` (must report
     CORRUPT and exit non-zero), then `gnomarchy backgrounds` and confirm it repairs.
   - Offline check: install with networking disabled and confirm the install still
     completes and every theme falls back to its bundled SVG wallpaper.
   - Drop an image into `~/.config/gnomarchy/backgrounds/nord/`, run
     `gnomarchy theme set nord`, and confirm your file wins over the downloaded one.
8. **Test Btrfs Snapshots**:
   ```bash
   gnomarchy snapshot create "Test Snapshot"
   gnomarchy snapshot list
   ```
   - Verify snapshot appears in Snapper and Limine boot menu upon reboot.

---

## 4. Migration Verification

Migrations are what carry config changes onto machines that are **already**
installed, so they need testing separately from a fresh install:

```bash
# On a machine installed from an older commit:
gnomarchy migrate --list      # should list pending migrations
gnomarchy update              # pulls, then applies them
gnomarchy migrate --list      # should now report none pending
```

Confirm each migration is idempotent by running `gnomarchy migrate` a second
time after clearing a single line from `~/.local/state/gnomarchy/migrations.log`:
re-running must not error or duplicate configuration (check that `gtk.css` still
has exactly one `gnomarchy-theme.css` import).

On a **fresh** install the ledger is baselined by
`install/post-install/migrations-baseline.sh`, so `gnomarchy migrate --list`
should report zero pending immediately after installation.
