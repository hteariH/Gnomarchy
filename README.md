# Gnomarchy Linux 🐧

<p align="center">
  <img src="assets/banner.png" alt="Gnomarchy Feature Graphic" width="100%">
</p>

<p align="center">
  <a href="https://gnomarchy.pages.dev"><img src="https://img.shields.io/badge/Website-gnomarchy.pages.dev-7aa2f7?style=for-the-badge&logo=cloudflarepages&logoColor=white" alt="Website"></a>
  <a href="https://github.com/hteariH/Gnomarchy/releases"><img src="https://img.shields.io/github/v/release/hteariH/Gnomarchy?style=for-the-badge&color=89b4fa&logo=github" alt="Release"></a>
  <img src="https://img.shields.io/badge/Arch%20Linux-Rolling-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white" alt="Arch Linux">
  <img src="https://img.shields.io/badge/GNOME-50-4a86cf?style=for-the-badge&logo=gnome&logoColor=white" alt="GNOME 50">
  <img src="https://img.shields.io/badge/Wayland-Native-f38ba8?style=for-the-badge&logo=wayland&logoColor=white" alt="Wayland">
  <img src="https://img.shields.io/badge/Btrfs-Snapper%20Rollbacks-a6e3a1?style=for-the-badge&logo=linux&logoColor=white" alt="Btrfs">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-fab387?style=for-the-badge" alt="License"></a>
</p>

> **The Power of Arch Linux and Omarchy's Developer Tooling Meets the Polish of GNOME.**

Gnomarchy is an opinionated, developer-first Linux distribution built on **Arch Linux**. It takes the modern rolling base, Btrfs + Snapper atomic rollback snapshots, hardware quirk mitigations, unified theme engine, and agentic CLI developer stack from **Omarchy**—and replaces the Hyprland tiling compositor stack with a finely tuned, keyboard-friendly **GNOME 50** desktop environment and **GDM**.

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
- **🛡️ Default Privacy Browser (Brave Origin)**: **Brave Origin** pre-configured as the default system browser—completely debloated of crypto, AI (Leo), rewards, and telemetry, delivering uncompromising speed and ad-blocking out of the box.
- **🖥️ Ubuntu-Style Left Dock (Dash to Dock)**: Full-height, clean left panel with pinned favorites (Terminal, Brave Origin, Files, Micro, Bazaar App Store).
- **📝 Modern Text Editing (Micro)**: Micro pre-installed and configured as the default system and CLI text editor (`$EDITOR`, `$VISUAL`, Git, and desktop MIME types).
- **🛍️ Flatpak & Bazaar App Store**: Out-of-the-box Flatpak and Flathub integration with **Bazaar**, the modern, native GNOME software store for Flatpaks.
- **💻 Curated Hardware Profiles**: Out-of-the-box fixes for Apple T2 Macs, Asus ROG laptops, Framework 13/16, Intel Panther Lake, and Nvidia hybrid graphics.

---

## Desktop Workflow & Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>T</kbd> | **Tactile Grid Tiling**: Launch interactive grid overlay to snap windows |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Launch **Alacritty** GPU-accelerated terminal |
| <kbd>Super</kbd> + <kbd>B</kbd> | Launch default web browser (**Brave Origin**) |
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

### Unified Theme Engine (22 Built-in Themes)

Gnomarchy includes **22 built-in themes** (18 Dark, 4 Light) matching the complete Omarchy palette suite. Every single theme comes bundled with a dedicated 4K vector wallpaper (installed to `/usr/share/backgrounds/gnomarchy/`), Libadwaita accent color, Alacritty palette, Neovim styling, and btop system monitor theme.

| Theme | Type | Accent | Aesthetic / Palette Style |
| :--- | :--- | :--- | :--- |
| **Tokyo Night** | Dark | `blue` | Deep indigo Tokyo city lights |
| **Catppuccin** | Dark | `purple` | Soothing pastel Mocha dark |
| **Catppuccin Latte** | Light | `blue` | Warm soft pastel daylight paper |
| **Ethereal** | Dark | `purple` | Mystical cosmic violet & nebula glow |
| **Everforest** | Dark | `green` | Natural soothing moss & pine green |
| **Flexoki Light** | Light | `orange` | Kepano's warm inky paper for deep reading |
| **Gruvbox** | Dark | `orange` | Classic warm retro groove & amber |
| **Hackerman** | Dark | `green` | Phosphor cyber green Matrix CRT void |
| **Kanagawa** | Dark | `teal` | Hokusai Great Wave wave-blue & sumi ink |
| **Last Horizon** | Dark | `orange` | Dusky twilight violet & sunset orange |
| **Lumon** | Dark | `teal` | Severance Kier Eagan corporate CRT teal |
| **Lupine** | Light | `purple` | Wildflower lavender & gentle daylight |
| **Matte Black** | Dark | `slate` | Industrial stealth dark & minimal zinc |
| **Miasma** | Dark | `green` | Deep decaying forest lichen & moss |
| **Nord** | Dark | `teal` | Arctic ice blue & Nordic slate |
| **Osaka Jade** | Dark | `green` | Imperial Japanese bamboo & deep jade |
| **Retro 82** | Dark | `pink` | 1982 arcade synthwave magenta & neon cyan |
| **Ristretto** | Dark | `orange` | Roasted espresso crema & cinnamon dark |
| **Rosé Pine** | Dark | `pink` | Warm rose petal, pine, and gold |
| **Solitude** | Dark | `slate` | Calm introspective midnight slate blue |
| **Vantablack** | Dark | `slate` | Ultra-minimal pure OLED true black |
| **White** | Light | `blue` | Pristine minimalist high-key paper light |

```bash
# List all 22 available themes with mode and accent details
gnomarchy theme list

# Switch to any theme instantly
gnomarchy theme set "kanagawa"
gnomarchy theme set "hackerman"
gnomarchy theme set "flexoki-light"

# Check active theme
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
