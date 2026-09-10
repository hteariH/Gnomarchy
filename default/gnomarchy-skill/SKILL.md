---
name: gnomarchy
description: Control and reconfigure the Gnomarchy Linux operating system, including GNOME settings, extensions, Tactile tiling, Dash to Dock, themes, flatpaks, and Btrfs snapshots.
---

# Gnomarchy OS Agent Skill

Use this skill whenever the user asks you to customize, reconfigure, automate, or troubleshoot their Gnomarchy Linux operating system.

Gnomarchy is an opinionated, developer-first Arch Linux distribution built with:
- **Desktop**: GNOME 47/48 (Wayland) + GDM
- **Dock**: Dash to Dock (Ubuntu-style left edge panel)
- **Tiling**: Tactile Grid Tiling (`<Super>T`)
- **Theme Engine**: Unified themes (7+ palettes: Tokyo Night, Catppuccin, Gruvbox, Everforest, Nord, Rose Pine, Matte Black)
- **Filesystem & Rollbacks**: Btrfs subvolumes (`@`, `@home`, `@snapshots`) + Snapper + Limine bootloader integration
- **Default Editor**: Micro (`$EDITOR`, `$VISUAL`, Git, and text/plain)
- **App Store & Packages**: Pacman, Flatpak (Flathub), and Bazaar

---

## Safety Protocol for AI Agents

> [!IMPORTANT]
> **Before performing any disruptive system, package, or configuration change:**
> Run a Btrfs rollback snapshot:
> ```bash
> gnomarchy snapshot create "Before agent change: <description of change>"
> ```
> This allows the user to immediately roll back any broken state directly from the Limine bootloader menu.

---

## 1. Theme Management

Gnomarchy syncs desktop themes across GNOME (accent color, dark/light mode, wallpaper), Alacritty terminal, Neovim, and btop.

```bash
# List available themes
gnomarchy theme list

# Check active theme
gnomarchy theme current

# Apply a theme
gnomarchy theme set "tokyo-night"
gnomarchy theme set "catppuccin"
gnomarchy theme set "gruvbox"
gnomarchy theme set "everforest"
gnomarchy theme set "nord"
gnomarchy theme set "rose-pine"
gnomarchy theme set "matte-black"
```

To create a custom user theme:
1. Create directory: `~/.config/gnomarchy/themes/<my-theme>/`
2. Add `accent.txt` containing one of: `blue`, `teal`, `green`, `yellow`, `orange`, `red`, `pink`, `purple`, `slate`.
3. Add `backgrounds/<image.jpg|png|svg>`.
4. Add `alacritty.toml`, `neovim.lua`, and `btop.theme`.
5. Run: `gnomarchy theme set "<my-theme>"`

---

## 2. Desktop Environment (GNOME & Mutter)

Use `gsettings` or the `gnomarchy gnome` CLI helpers.

### Display Scaling & Fractional Scaling
```bash
# Enable Wayland fractional scaling in GNOME Settings -> Displays
gnomarchy gnome scaling enable

# Set font/text scaling factor directly
gnomarchy gnome scaling text 1.25
```

### Night Light
```bash
# Turn night light on or off
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 3500
```

### Power & Behavior
```bash
# Don't sleep while on AC power
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'

# Center new windows
gsettings set org.gnome.mutter center-new-windows true
```

---

## 3. Ubuntu-Style Dock (Dash to Dock)

Configuration schema: `org.gnome.shell.extensions.dash-to-dock`

```bash
# Adjust icon size
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 44

# Enable/disable auto-hide (intellihide)
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true     # Persistent Ubuntu panel
gsettings set org.gnome.shell.extensions.dash-to-dock intellihide false   # Do not auto-hide

# Change dock position ('LEFT', 'BOTTOM', 'RIGHT', 'TOP')
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT'

# Pin or reorder favorite applications in the dock
gsettings get org.gnome.shell favorite-apps
gsettings set org.gnome.shell favorite-apps "['chromium.desktop', 'alacritty.desktop', 'org.gnome.Nautilus.desktop', 'micro.desktop', 'io.github.kolunmi.Bazaar.desktop', 'org.gnome.Settings.desktop']"
```

---

## 4. Tiling Management (Tactile)

Tactile provides modal keyboard-driven window snapping on `<Super>T`.

Configuration schema: `org.gnome.shell.extensions.tactile`

```bash
# Adjust window gap size (in pixels)
gsettings set org.gnome.shell.extensions.tactile gap-size 20

# Change grid layout (columns & rows)
gsettings set org.gnome.shell.extensions.tactile col-0 1
gsettings set org.gnome.shell.extensions.tactile col-1 2
gsettings set org.gnome.shell.extensions.tactile col-2 1
gsettings set org.gnome.shell.extensions.tactile row-0 1
gsettings set org.gnome.shell.extensions.tactile row-1 1

# Change trigger hotkey
gsettings set org.gnome.shell.extensions.tactile show-tiles "['<Super>t']"
```

---

## 5. Extensions Management

```bash
# List active extensions
gnomarchy gnome extensions list

# Enable or disable an extension
gnomarchy gnome extensions enable <uuid>
gnomarchy gnome extensions disable <uuid>

# Reset all extensions to Gnomarchy stock defaults
gnomarchy gnome extensions reset
```

---

## 6. Keyboard Shortcuts

Inspect active shortcuts:
```bash
gnomarchy gnome hotkeys
```

To add a new custom shortcut, register under `/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/`:
```bash
# Example: Bind Super+N to open Micro in terminal
BINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4"
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
  "$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings | sed "s/]/, '$BINDING_PATH\/']/ \")"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/ name 'Micro Editor'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/ command 'alacritty -e micro'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$BINDING_PATH/ binding '<Super>n'
```

---

## 7. Package & Flatpak Management

```bash
# Install Arch package via pacman
sudo pacman -S --needed <package>

# Search or install Flatpaks from Flathub
flatpak search <app>
flatpak install -y flathub <app-id>

# Launch Bazaar Flatpak software center
flatpak run io.github.kolunmi.Bazaar
```

---

## 8. Rollback Snapshots

```bash
# List all current Btrfs snapshots
gnomarchy snapshot list

# Create a snapshot before making system modifications
gnomarchy snapshot create "Pre-refactor snapshot"
```

---

## 9. Web Applications (`gnomarchy webapp`)

Turn any web URL into an isolated desktop application launcher with its own profile and Dash to Dock support:

```bash
# Add a web application
gnomarchy webapp add "Claude" "https://claude.ai"
gnomarchy webapp add "ChatGPT" "https://chatgpt.com"
gnomarchy webapp add "Linear" "https://linear.app"

# List web apps
gnomarchy webapp list

# Remove a web app
gnomarchy webapp remove "Claude"
```

---

## 10. Desktop Reminders (`gnomarchy reminder`)

Schedule desktop notifications with chime alerts:

```bash
# Duration-based reminders
gnomarchy reminder 25m "Pomodoro break"
gnomarchy reminder 1h30m "Review deployment logs"

# Clock-based reminders
gnomarchy reminder 17:30 "Team Standup"

# List or cancel active reminders
gnomarchy reminder list
gnomarchy reminder cancel <reminder-id>
```

---

## 11. Voxtype AI Speech-to-Text (`gnomarchy voxtype`)

System-wide speech-to-text powered by local offline Whisper models:

```bash
# Toggle recording (also bound to Super+D)
gnomarchy voxtype toggle

# Manual controls
gnomarchy voxtype start
gnomarchy voxtype stop
gnomarchy voxtype status
```

---

## 12. Windows 11 VM (`gnomarchy windows`)

Hardware-accelerated Windows 11 virtual machine using KVM, VirtIO, and TPM 2.0:

```bash
gnomarchy windows setup     # Provision VM storage & environment
gnomarchy windows start     # Boot Windows 11 VM
gnomarchy windows stop      # Cleanly stop VM
gnomarchy windows status    # Check VM state and disk usage
```

---

## 13. Event Hooks (`~/.config/gnomarchy/hooks/`)

Subscribe to Gnomarchy system events:
- `on-theme-change <theme-name>`: Triggered when theme is switched.
- `on-snapshot <description>`: Triggered after Btrfs snapshot creation.
- `on-update <pre|post>`: Triggered before/after system updates.
- `on-webapp-add <name> <url>`: Triggered when a new web app is added.

Trigger hooks manually:
```bash
gnomarchy hook on-theme-change "tokyo-night"
```
