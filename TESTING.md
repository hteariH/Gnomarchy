# Gnomarchy Verification & Testing Guide

This guide details the procedure for testing Gnomarchy scripts, the live ISO build, and the installed GNOME environment.

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
   - <kbd>Super</kbd> + <kbd>Return</kbd>: Launches Alacritty with JetBrains Mono font.
   - <kbd>Super</kbd> + <kbd>1</kbd>–<kbd>6</kbd>: Switches workspaces.
   - <kbd>Super</kbd> + <kbd>W</kbd>: Closes active window.
3. **Test Theme Engine**:
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
     - Alacritty window background and foreground update.
     - Neovim theme updates on launch.
4. **Test Btrfs Snapshots**:
   ```bash
   gnomarchy snapshot create "Test Snapshot"
   gnomarchy snapshot list
   ```
   - Verify snapshot appears in Snapper and Limine boot menu upon reboot.
