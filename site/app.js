/**
 * Gnomarchy — Interactive Client Application
 * Theme engine, Tactile Grid simulator, Voxtype AI wave generator, and CLI playground
 */

(function () {
  'use strict';

  // --- Themes System ---
  const THEMES = [
    { id: 'tokyo-night', name: 'Tokyo Night' },
    { id: 'catppuccin', name: 'Catppuccin' },
    { id: 'gruvbox', name: 'Gruvbox' },
    { id: 'everforest', name: 'Everforest' },
    { id: 'nord', name: 'Nord' },
    { id: 'rose-pine', name: 'Rosé Pine' },
    { id: 'matte-black', name: 'Matte Black' }
  ];

  let currentThemeIndex = 0;

  function applyTheme(themeId) {
    const idx = THEMES.findIndex(t => t.id === themeId);
    if (idx !== -1) currentThemeIndex = idx;
    const theme = THEMES[currentThemeIndex];

    if (theme.id === 'tokyo-night') {
      delete document.documentElement.dataset.theme;
    } else {
      document.documentElement.dataset.theme = theme.id;
    }

    try {
      localStorage.setItem('gnomarchy-theme', theme.id);
    } catch (e) {}

    const navLabel = document.getElementById('navThemeLabel');
    if (navLabel) navLabel.textContent = theme.name;

    document.querySelectorAll('[data-theme-target]').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.themeTarget === theme.id);
    });
  }

  function cycleTheme() {
    currentThemeIndex = (currentThemeIndex + 1) % THEMES.length;
    applyTheme(THEMES[currentThemeIndex].id);
  }

  // Global 'T' key listener
  window.addEventListener('keydown', e => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    if (e.key === 't' || e.key === 'T') {
      cycleTheme();
    }
  });

  // --- Tactile Grid Simulator ---
  function setupTactileSimulator() {
    const buttons = document.querySelectorAll('[data-grid-slot]');
    const win = document.getElementById('tactileMockWindow');
    const title = document.getElementById('tactileMockTitle');
    if (!buttons.length || !win) return;

    buttons.forEach(btn => {
      btn.addEventListener('click', () => {
        buttons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        const slot = btn.dataset.gridSlot;
        if (slot === 'left') {
          win.style.left = '16px';
          win.style.width = 'calc(50% - 24px)';
          if (title) title.textContent = 'Alacritty — Snapped Left 50%';
        } else if (slot === 'right') {
          win.style.left = 'calc(50% + 8px)';
          win.style.width = 'calc(50% - 24px)';
          if (title) title.textContent = 'Brave Origin — Snapped Right 50%';
        } else if (slot === 'center') {
          win.style.left = '15%';
          win.style.width = '70%';
          if (title) title.textContent = 'Neovim — Focused Center 70%';
        } else if (slot === 'full') {
          win.style.left = '16px';
          win.style.width = 'calc(100% - 32px)';
          if (title) title.textContent = 'GNOME Workstation — Maximized';
        }
      });
    });
  }

  // --- Voxtype AI Voice Wave Simulator ---
  function setupVoxtypeSimulator() {
    const btn = document.getElementById('simulateVoiceBtn');
    const statusLabel = document.getElementById('voiceStatusLabel');
    const transcript = document.getElementById('voiceTranscript');
    const bars = document.querySelectorAll('#audioWaveVisualizer .audio-bar');
    if (!btn) return;

    let isSimulating = false;

    const phrases = [
      "Refactor the authentication handler to use Btrfs atomic subvolume snapshots.",
      "Switch system theme to Everforest and reload Alacritty terminal.",
      "Convert linear.app to an isolated desktop web application.",
      "Set a reminder for 25 minutes to review pull request 402."
    ];
    let phraseIdx = 0;

    btn.addEventListener('click', () => {
      if (isSimulating) return;
      isSimulating = true;

      if (statusLabel) {
        statusLabel.textContent = '🎙️ LISTENING (PIPEWIRE 48kHz)...';
        statusLabel.style.color = 'var(--accent)';
      }
      if (transcript) transcript.textContent = 'Listening to speech input...';

      let count = 0;
      const interval = setInterval(() => {
        bars.forEach(bar => {
          const h = Math.floor(Math.random() * 42) + 8;
          bar.style.height = `${h}px`;
        });
        count++;

        if (count > 16) {
          clearInterval(interval);
          bars.forEach((bar, i) => {
            const defaultHeights = [14, 24, 36, 48, 28, 18, 40, 30, 12];
            bar.style.height = `${defaultHeights[i % defaultHeights.length]}px`;
          });
          if (statusLabel) {
            statusLabel.textContent = '✔ TRANSCRIBED (LOCAL WHISPER)';
            statusLabel.style.color = 'var(--color-green)';
          }
          if (transcript) {
            transcript.textContent = `"${phrases[phraseIdx % phrases.length]}"`;
            phraseIdx++;
          }
          isSimulating = false;
        }
      }, 100);
    });
  }

  // --- Master CLI Playground ---
  const CLI_ENTRIES = {
    theme: {
      cmd: 'gnomarchy theme set "nord"',
      output: `[gnomarchy] Switching active system theme to 'nord'...
✔ GNOME Libadwaita accent color -> #88c0d0
✔ Alacritty terminal theme updated (~/.config/alacritty/alacritty.toml)
✔ Neovim color scheme synchronized (~/.config/nvim/init.lua)
✔ btop system monitor theme updated
✔ Wallpaper set: ~/.config/gnomarchy/themes/nord/backgrounds/nord.svg
✔ Dispatched lifecycle hook: ~/.config/gnomarchy/hooks/on-theme-change
Theme switch applied across all applications instantaneously.`
    },
    snapshot: {
      cmd: 'gnomarchy snapshot create "Before system refactor"',
      output: `[gnomarchy] Creating atomic Btrfs subvolume snapshot...
✔ Snapper created pre-snapshot #91
✔ Subvolumes captured: @ (root), @home, @var_log
✔ Updated Limine boot menu entries (/boot/limine.cfg)
Snapshot complete. Select '#91: Before system refactor' from boot menu to roll back anytime.`
    },
    webapp: {
      cmd: 'gnomarchy webapp add "Claude" "https://claude.ai"',
      output: `[gnomarchy] Generating isolated web application for 'Claude'...
✔ Fetching highest-res favicon from https://claude.ai/favicon.ico
✔ Created desktop entry: ~/.local/share/applications/claude-webapp.desktop
✔ Configured isolated Brave Origin browser profile: ~/.local/share/gnomarchy/webapps/Claude
✔ Pinned Claude to GNOME Dash to Dock favorites panel
Web App 'Claude' is ready. Launch via Super key or Dash.`
    },
    reminder: {
      cmd: 'gnomarchy reminder 25m "Pomodoro break"',
      output: `[gnomarchy] Reminder scheduled!
ID:        #405
Alarm:     25 minutes from now
Message:   "Pomodoro break"
Sound:     Subtle GNOME chime enabled
Run 'gnomarchy reminder list' to view active alarms.`
    },
    windows: {
      cmd: 'gnomarchy windows start',
      output: `[gnomarchy] Booting Windows 11 KVM Virtual Machine...
✔ QEMU/KVM hypervisor acceleration active
✔ VirtIO fast storage & VirtIO network adapters attached
✔ swtpm Software TPM 2.0 active
✔ Shared clipboard & host folder: ~/WindowsShare
Windows 11 desktop launched in seamless Wayland window.`
    }
  };

  function setupCliPlayground() {
    const tabs = document.querySelectorAll('.cli-tab');
    const cmdDisplay = document.getElementById('cliCmdDisplay');
    const outDisplay = document.getElementById('cliOutputDisplay');
    const copyBtn = document.getElementById('cliCopyBtn');

    tabs.forEach(tab => {
      tab.addEventListener('click', () => {
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');

        const key = tab.dataset.cmd;
        const entry = CLI_ENTRIES[key];
        if (entry && cmdDisplay && outDisplay) {
          cmdDisplay.textContent = entry.cmd;
          outDisplay.textContent = entry.output;
        }
      });
    });

    if (copyBtn && cmdDisplay) {
      copyBtn.addEventListener('click', () => {
        copyText(cmdDisplay.textContent, copyBtn);
      });
    }
  }

  // --- Copy Helper ---
  function copyText(text, el) {
    const orig = el.textContent;
    const notify = () => {
      el.textContent = 'Copied!';
      setTimeout(() => { el.textContent = orig; }, 1600);
    };

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(notify).catch(() => fallbackCopy(text, notify));
    } else {
      fallbackCopy(text, notify);
    }
  }

  function fallbackCopy(text, cb) {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    try {
      document.execCommand('copy');
      if (cb) cb();
    } catch (e) {}
    document.body.removeChild(ta);
  }

  // --- Initialize ---
  document.addEventListener('DOMContentLoaded', () => {
    try {
      const saved = localStorage.getItem('gnomarchy-theme') || 'tokyo-night';
      applyTheme(saved);
    } catch (e) {
      applyTheme('tokyo-night');
    }

    document.querySelectorAll('[data-theme-target]').forEach(btn => {
      btn.addEventListener('click', () => {
        applyTheme(btn.dataset.themeTarget);
      });
    });

    const navToggle = document.getElementById('navThemeToggleBtn');
    if (navToggle) {
      navToggle.addEventListener('click', cycleTheme);
    }

    document.querySelectorAll('[data-copy-cmd]').forEach(el => {
      el.addEventListener('click', () => {
        const cmd = el.getAttribute('data-copy-cmd');
        copyText(cmd, el);
      });
    });

    setupTactileSimulator();
    setupVoxtypeSimulator();
    setupCliPlayground();
  });
})();
