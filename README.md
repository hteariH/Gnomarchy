# Gnomarchy Linux 🐧

<p align="center">
  <img src="assets/banner.png" alt="Gnomarchy Feature Graphic" width="100%">
</p>

<p align="center">
  <a href="https://github.com/hteariH/Gnomarchy/releases"><img src="https://img.shields.io/github/v/release/hteariH/Gnomarchy?style=for-the-badge&color=89b4fa&logo=github" alt="Release"></a>
  <img src="https://img.shields.io/badge/Arch%20Linux-Rolling-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white" alt="Arch Linux">
  <img src="https://img.shields.io/badge/GNOME-47%20%2F%2048-4a86cf?style=for-the-badge&logo=gnome&logoColor=white" alt="GNOME">
  <img src="https://img.shields.io/badge/Wayland-Native-f38ba8?style=for-the-badge&logo=wayland&logoColor=white" alt="Wayland">
  <img src="https://img.shields.io/badge/Btrfs-Snapper%20Rollbacks-a6e3a1?style=for-the-badge&logo=linux&logoColor=white" alt="Btrfs">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-fab387?style=for-the-badge" alt="License"></a>
</p>

> **The Power of Arch Linux and Omarchy's Developer Tooling Meets the Polish of GNOME.**

Gnomarchy is an opinionated, developer-first Linux distribution built on **Arch Linux**. It takes the modern rolling base, Btrfs + Snapper atomic rollback snapshots, hardware quirk mitigations, unified theme engine, and agentic CLI developer stack from **Omarchy**—and replaces the Hyprland tiling compositor stack with a finely tuned, keyboard-friendly **GNOME 47/48** desktop environment and **GDM**.

---

## Highlights & Features

- **🎨 Unified Cross-Desktop Theme Engine**: Change your entire system theme—GNOME Libadwaita accent color, dark/light mode, wallpapers, Alacritty terminal, Neovim, btop, and VS Code—with a single command (`gnomarchy theme set <name>`).
- **🧩 Tactile Grid Tiling (`Super + T`)**: Avoid the rigid complexity of automatic tiling window managers while keeping lightning-fast keyboard window positioning inspired by DHH's Omakub.
- **🎙️ Voxtype (System-Wide AI Dictation)**: Speech-to-text dictation on `<Super>D` powered by local, offline Whisper AI models with zero cloud fees and zero telemetry.
- **🌐 Web App Generator (`gnomarchy webapp`)**: Turn web tools (Claude, ChatGPT, Linear, Notion, Basecamp) into standalone desktop apps with isolated profiles, auto-fetched favicons, and Dash to Dock pinning.
- **📁 Nautilus Context Superpowers**: Native right-click file actions for fast video compression for Discord/Slack (25MB), GIF creation, MP3 extraction, WebP conversion, EXIF stripping, and LocalSend sharing.
- **🪟 Windows 11 VM Automation (`gnomarchy windows`)**: One-command creation and execution of hardware-accelerated Windows 11 KVM VMs with VirtIO and software TPM 2.0 (`swtpm`).
- **⏰ Desktop Reminders & Alarms (`gnomarchy reminder`)**: Instant notification alarms with chime audio cues for pomodoro breaks, standups, or deploy checks.
- **🤖 AI Agent OS Control Layer & Lifecycle Hooks**: Pre-installed agent skill (`AGENTS.md`) and hooks directory (`~/.config/gnomarchy/hooks/`) allowing Claude Code, Antigravity, OpenCode, or user scripts to orchestrate and react to system events.
- **🛡️ Bulletproof Btrfs & Snapper Rollbacks**: Automated boot snapshots integrated with the Limine bootloader let you roll back kernel or package updates directly from the boot menu.
- **⚡ Fast Shutdown Tuning**: Systemd timeout stop limits tuned from 90s down to 10s for instantaneous power-offs and reboots.
- **👾 Retro Terminal Screensaver (`gnomarchy screensaver`)**: Fullscreen matrix rain screensaver triggered via `<Super>Escape`.
- **🖥️ Ubuntu-Style Left Dock (Dash to Dock)**: Full-height, clean left panel with pinned favorites (Terminal, Browser, Files, Micro, Bazaar App Store).
- **📝 Modern Text Editing (Micro)**: Micro pre-installed and configured as the default system and CLI text editor (`$EDITOR`, `$VISUAL`, Git, and desktop MIME types).
- **🛍️ Flatpak & Bazaar App Store**: Out-of-the-box Flatpak and Flathub integration with **Bazaar**, the modern, native GNOME software store for Flatpaks.
- **💻 Curated Hardware Profiles**: Out-of-the-box fixes for Apple T2 Macs, Asus ROG laptops, Framework 13/16, Intel Panther Lake, and Nvidia hybrid graphics.

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
| <kbd>Super</kbd> + <kbd>D</kbd> | **Voxtype**: Toggle AI Speech-to-Text Dictation |
| <kbd>Super</kbd> + <kbd>Escape</kbd> | **Screensaver**: Fullscreen Retro Matrix terminal screensaver |
| <kbd>Print</kbd> | Native GNOME interactive screenshot & recording grabber |
| <kbd>Ctrl</kbd> + <kbd>Print</kbd> | Area screenshot with **Satty** annotation editor |

---

## Installation

### Method 1: Bootable Installation ISO (Recommended)

1. Download the latest `gnomarchy-linux-*.iso` from [Releases](https://github.com/hteariH/Gnomarchy/releases).
2. Flash to a USB drive using `dd`, `balenaEtcher`, or `caligula`:
   ```bash
   sudo dd if=gnomarchy-linux.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
3. Boot your system in **UEFI mode** with Secure Boot temporarily disabled.
4. The automated installer will launch on TTY1, partition your drive with Btrfs subvolumes (`@`, `@home`, `@snapshots`, `@var_log`, `@var_cache`), optionally set up LUKS2 disk encryption, install packages, configure Limine + Snapper, and deploy the desktop.

### Method 2: Quick Install Over Clean Arch Linux

If you have already installed a minimal base Arch Linux system:

```bash
curl -fsSL https://raw.githubusercontent.com/hteariH/Gnomarchy/main/boot.sh | bash
```

---

## Master CLI Dispatcher (`gnomarchy`)

Control the desktop and OS layer using the `gnomarchy` CLI:

### Theme Management
```bash
# List available color schemes
gnomarchy theme list

# Switch theme (tokyo-night, catppuccin, gruvbox, everforest, nord, rose-pine, matte-black)
gnomarchy theme set "tokyo-night"
gnomarchy theme set "catppuccin"

# Show current theme
gnomarchy theme current
```

### Web Applications
```bash
# Convert web apps into isolated desktop applications
gnomarchy webapp add "Claude" "https://claude.ai"
gnomarchy webapp add "Linear" "https://linear.app"

# List and remove web apps
gnomarchy webapp list
gnomarchy webapp remove "Claude"
```

### Desktop Reminders
```bash
# Set relative countdowns or exact time reminders with sound cues
gnomarchy reminder 25m "Pomodoro break"
gnomarchy reminder 1h30m "Review PR"
gnomarchy reminder 17:30 "Team Standup"

# List and cancel active reminders
gnomarchy reminder list
gnomarchy reminder cancel <id>
```

### Voxtype AI Speech-to-Text
```bash
# Toggle audio capture and transcription (or press Super+D)
gnomarchy voxtype toggle
gnomarchy voxtype status
```

### Windows 11 VM Automation
```bash
# Setup and launch hardware-accelerated Windows 11 KVM VM
gnomarchy windows setup
gnomarchy windows start
gnomarchy windows status
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

### System Updates & Lifecycle Hooks
```bash
# Synchronize Arch packages, AUR packages, and Gnomarchy configuration
gnomarchy update

# Trigger or inspect lifecycle event hooks (~/.config/gnomarchy/hooks/)
gnomarchy hook on-theme-change "tokyo-night"
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

Gnomarchy is open-source software licensed under the **[MIT License](LICENSE)**.
