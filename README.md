# Gnomarchy Linux 🐧

> **The Power of Arch Linux and Omarchy's Developer Tooling Meets the Polish of GNOME.**

Gnomarchy is an opinionated, developer-first Linux distribution built on **Arch Linux**. It takes the modern rolling base, Btrfs + Snapper atomic rollback snapshots, hardware quirk mitigations, unified theme engine, and agentic CLI developer stack from **Omarchy**—and replaces the Hyprland tiling compositor stack with a finely tuned, keyboard-friendly **GNOME 47/48** desktop environment and **GDM**.

---

## Why Gnomarchy?

- **Zero-Friction Multi-Monitor & Fractional Scaling**: Enjoy Wayland-native monitor hotplugging, per-display fractional scaling, and HDR support backed by Mutter and GNOME Shell.
- **Tactile Grid Tiling (`Super + T`)**: Avoid the rigid complexity of automatic tiling window managers while keeping lightning-fast keyboard window positioning inspired by DHH's Omakub.
- **Unified Cross-Desktop Theme Engine**: Change your entire system theme—GNOME Libadwaita accent color, dark/light mode, wallpapers, Alacritty terminal, Neovim, btop, and VS Code—with a single command (`gnomarchy theme set <name>`).
- **Bulletproof Btrfs & Snapper Rollbacks**: Automated boot snapshots integrated with the Limine bootloader let you roll back kernel or package updates directly from the boot menu.
- **Ubuntu-Style Left Dock (Dash to Dock)**: Full-height, clean left panel with pinned favorites (Terminal, Browser, Files, Micro, Bazaar App Store).
- **Modern Text Editing (Micro)**: Micro pre-installed and configured as the default system and CLI text editor (`$EDITOR`, `$VISUAL`, Git, and desktop MIME types).
- **Flatpak & Bazaar App Store**: Out-of-the-box Flatpak and Flathub integration with **Bazaar**, the modern, native GNOME software store for Flatpaks.
- **Turnkey Developer Stack**: Pre-configured with Micro, Neovim, Alacritty, Starship, Docker, Lazygit, Lazydocker, Mise (multi-language version management), and AI agent tooling.
- **Curated Hardware Profiles**: Out-of-the-box fixes for Apple T2 Macs, Asus ROG laptops, Framework 13/16, Intel Panther Lake, and Nvidia hybrid graphics.

---

## Desktop Workflow & Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>T</kbd> | **Tactile Grid Tiling**: Launch interactive grid overlay to snap windows |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Launch **Alacritty** GPU-accelerated terminal |
| <kbd>Super</kbd> + <kbd>B</kbd> | Launch default web browser (**Chromium**) |
| <kbd>Super</kbd> + <kbd>E</kbd> | Open **Nautilus** file manager |
| <kbd>Super</kbd> | Open **GNOME Overview** & Instant App Search |
| <kbd>Super</kbd> + <kbd>W</kbd> | Close focused window |
| <kbd>Super</kbd> + <kbd>Up</kbd> | Maximize focused window |
| <kbd>Super</kbd> + <kbd>Backspace</kbd> | Interactive window resize mode |
| <kbd>Super</kbd> + <kbd>1</kbd> – <kbd>6</kbd> | Switch directly to workspace 1 through 6 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1</kbd> – <kbd>6</kbd> | Move focused window to workspace 1 through 6 |
| <kbd>Print</kbd> | Native GNOME interactive screenshot & recording grabber |
| <kbd>Ctrl</kbd> + <kbd>Print</kbd> | Area screenshot with **Satty** annotation editor |

---

## Installation

### Method 1: Bootable Installation ISO (Recommended for New Machines)

1. Download the latest `gnomarchy-linux-*.iso` from releases (or build your own using `iso/builder/build-iso.sh`).
2. Flash to a USB drive using `dd`, `balenaEtcher`, or `caligula`:
   ```bash
   sudo dd if=gnomarchy-linux.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
3. Boot your system in **UEFI mode** with Secure Boot temporarily disabled.
4. The automated installer will launch on TTY1, partition your drive with Btrfs subvolumes, optionally set up LUKS2 disk encryption, install base packages, configure Limine + Snapper, and deploy the Gnomarchy desktop.

### Method 2: Quick Install Over Clean Arch Linux

If you have already installed a minimal base Arch Linux system:

```bash
curl -fsSL https://raw.githubusercontent.com/hteariH/Gnomarchy/main/boot.sh | bash
```

---

## The Gnomarchy CLI (`gnomarchy`)

Gnomarchy includes a unified CLI to control your desktop and system:

### Theme Management
```bash
# List available color schemes
gnomarchy theme list

# Switch theme (Tokyo Night, Catppuccin, Gruvbox, Everforest, Nord, Rose Pine, Matte Black)
gnomarchy theme set "tokyo-night"
gnomarchy theme set "catppuccin"

# Show current theme
gnomarchy theme current
```

### GNOME Management
```bash
# List active GNOME extensions
gnomarchy gnome extensions list

# Reset extensions to default Gnomarchy configuration
gnomarchy gnome extensions reset

# Show keyboard shortcuts guide or reset to defaults
gnomarchy gnome hotkeys
gnomarchy gnome hotkeys reset

# Enable experimental fractional scaling support
gnomarchy gnome scaling enable
```

### Rollback Snapshots
```bash
# Create an atomic snapshot before doing risky work
gnomarchy snapshot create "Before system refactor"

# List snapshots
gnomarchy snapshot list
```

### System Updates
```bash
# Synchronize Arch packages, AUR packages, and Gnomarchy configuration
gnomarchy update
```

---

## Building the ISO Locally

To build your own bootable Gnomarchy ISO:

```bash
# Install archiso on an Arch host
sudo pacman -S archiso git

# Run the ISO builder
sudo ./iso/builder/build-iso.sh
```

The resulting ISO will be generated in `./out/`. You can test it immediately in QEMU:

```bash
./run-vm.sh
```

---

## License

Gnomarchy is open-source software licensed under the **MIT License**.
