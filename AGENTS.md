# Gnomarchy: AI Agent Instructions & Operating Protocol

Welcome! You are operating on a **Gnomarchy Linux** system. Gnomarchy is designed as an agentic workstation where AI coding agents can configure, optimize, and manage the system on the user's behalf.

---

## Safety Protocol: Always Snapshot Before Changing the System

Whenever performing potentially breaking configuration edits, package changes, or system reconfigurations:

```bash
gnomarchy snapshot create "Before agent action: <summary>"
```

This guarantees the user can roll back any state instantly from the Limine boot menu upon reboot.

---

## Command Suite: `gnomarchy`

Use the high-level `gnomarchy` CLI dispatcher whenever available:

| Task | Command |
| :--- | :--- |
| **Open command center** | `gnomarchy menu` (or `<Super><Alt>space`) |
| **List themes** | `gnomarchy theme list` |
| **Check active theme** | `gnomarchy theme current` |
| **Fetch wallpapers** | `gnomarchy backgrounds` (downloaded, not shipped - see BACKGROUNDS.md) |
| **Switch tiling mode** | `gnomarchy tiling <enable\|disable\|status>` (dynamic vs manual) |
| **Set theme** | `gnomarchy theme set <name>` (22 built-in themes, e.g. `tokyo-night`, `catppuccin`, `kanagawa`, `hackerman`, `flexoki-light`) |
| **Create Web App** | `gnomarchy webapp add "<Name>" "<URL>"` |
| **List Web Apps** | `gnomarchy webapp list` |
| **Remove Web App** | `gnomarchy webapp remove "<Name>"` |
| **Set Reminder** | `gnomarchy reminder <25m|1h|17:30> "<Message>"` |
| **List Reminders** | `gnomarchy reminder list` |
| **Cancel Reminder** | `gnomarchy reminder cancel <id>` |
| **Toggle AI Dictation** | `gnomarchy voxtype toggle` (or `<Super>d`) |
| **Windows 11 VM** | `gnomarchy windows <setup|start|stop|status>` |
| **Screen capture** | `gnomarchy capture <annotate\|region\|screen>` |
| **Screensaver** | `gnomarchy screensaver` (or `<Super>Escape`) |
| **Trigger Hook** | `gnomarchy hook <hook-name> [args...]` |
| **List GNOME extensions** | `gnomarchy gnome extensions list` |
| **Enable/disable extension** | `gnomarchy gnome extensions <enable|disable> <uuid>` |
| **Reset extensions** | `gnomarchy gnome extensions reset` |
| **Inspect shortcuts** | `gnomarchy gnome hotkeys` |
| **Enable fractional scaling**| `gnomarchy gnome scaling enable` |
| **Text scaling factor** | `gnomarchy gnome scaling text 1.25` |
| **Refresh desktop** | `gnomarchy gnome restart` |
| **Create snapshot** | `gnomarchy snapshot create "<description>"` |
| **List snapshots** | `gnomarchy snapshot list` |
| **Update system** | `gnomarchy update` (pacman + AUR + git pull + migrations) |
| **Inspect migrations** | `gnomarchy migrate --list` |
| **Show version** | `gnomarchy version [--verbose]` |

---

## Desktop Customization Protocols

### 1. GNOME Settings (`gsettings`)
All desktop settings are managed via GSettings.
- Mutter / Window placement: `org.gnome.mutter`
- Interface fonts & theme mode: `org.gnome.desktop.interface`
- Ubuntu-style Dock: `org.gnome.shell.extensions.dash-to-dock`
- Tactile Tiling: `org.gnome.shell.extensions.tactile`
- Workspaces: `org.gnome.desktop.wm.preferences`

### 2. Tiling Window Management

Two mutually exclusive modes; never enable both, they fight over placement.

- **Dynamic** (opt-in): Tiling Shell, `org.gnome.shell.extensions.tilingshell`.
  The switch that matters is `enable-autotiling`; without it new windows still
  open floating. Focus/move bindings are `focus-window-*` / `move-window-*`.
- **Manual** (default): Tactile, below.

Switch with `gnomarchy tiling <enable|disable>` rather than toggling the
extensions by hand.

#### Tactile (manual)
- Trigger key: `<Super>T`
- Gap size: `gsettings set org.gnome.shell.extensions.tactile gap-size <pixels>`
- Grid layout: `gsettings set org.gnome.shell.extensions.tactile col-0 <span-ratio>`

### 3. Ubuntu-Style Dock (Dash to Dock)
- Pinned to left: `gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT'`
- Fixed panel: `gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true`
- Pinned favorites: `gsettings set org.gnome.shell favorite-apps "[ '<app1>.desktop', ... ]"`

### 4. Shipping Configuration Changes to Installed Machines

Editing a file in this repo only changes **new** installs. To change a machine
that is already running Gnomarchy, add a migration:

- Create `migrations/<YYYY-MM-DD-HHMM>-<slug>.sh`.
- Make it **idempotent** - it may run on machines in any prior state.
- It runs once per machine, recorded in `~/.local/state/gnomarchy/migrations.log`.
- `gnomarchy update` applies pending migrations after the git pull.

### 5. Text Editor & Default Applications
- Default text editor is **Micro**.
- CLI: `micro <file>` (also `$EDITOR` and `$VISUAL`).
- Default web browser is **Brave Origin** (`brave-origin` / `brave`).
- File manager: `nautilus`.
- Terminal: **gnome-terminal** is the default. Its colors live in dconf under the
  Gnomarchy profile (`b1dcc9dd-5262-4d8d-a863-c897e6d979b9`) and are owned by the
  theme engine - never set them by hand.
- Alacritty remains installed as a secondary terminal (config at
  `~/.config/alacritty/alacritty.toml`; `colors.toml` is theme-engine owned).
  Each theme's `alacritty.toml` is the canonical 16-color palette source for
  **both** terminals.
- Neovim: **LazyVim**, bootstrapped at `~/.config/nvim`. `lua/plugins/theme.lua` and
  `lua/plugins/gnomarchy-colorscheme.lua` are generated by the theme engine.
- App Store: `bazaar` (`io.github.kolunmi.Bazaar`).

---

## Script & Code Standards

- **Bash Shebang**: `#!/bin/bash`
- **Conditionals**: Prefer `[[ ]]` for string tests and `(( ))` for arithmetic.
- **Paths**: Never hardcode user paths; use `$HOME` or `~`.
- **Permissions**: Ensure scripts have `chmod +x` before execution.
