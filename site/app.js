/**
 * Gnomarchy — Interactive Client Application
 * Theme cycling, CLI simulator, clipboard helpers & keyboard interactions
 */

(function () {
  'use strict';

  // --- Themes Configuration ---
  const THEMES = [
    {
      id: 'tokyo-night',
      name: 'Tokyo Night',
      accent: '#7aa2f7',
      bg: '#1a1b26',
      colors: ['#1a1b26', '#7aa2f7', '#9ece6a', '#e0af68', '#f7768e', '#bb9af7'],
      desc: 'Deep Tokyo midnight navy with vibrant neon highlights and cyan glows.'
    },
    {
      id: 'catppuccin',
      name: 'Catppuccin Mocha',
      accent: '#89b4fa',
      bg: '#1e1e2e',
      colors: ['#1e1e2e', '#89b4fa', '#a6e3a1', '#f9e2af', '#f38ba8', '#cba6f7'],
      desc: 'Soothing, warm pastel palette crafted for frictionless daily workflows.'
    },
    {
      id: 'gruvbox',
      name: 'Gruvbox',
      accent: '#fabd2f',
      bg: '#282828',
      colors: ['#282828', '#fabd2f', '#b8bb26', '#8ec07c', '#fb4934', '#d3869b'],
      desc: 'Retro groove aesthetic with warm earthy tones, amber accents, and soft contrast.'
    },
    {
      id: 'everforest',
      name: 'Everforest',
      accent: '#a7c080',
      bg: '#2d353b',
      colors: ['#2d353b', '#a7c080', '#83c092', '#dbbc7f', '#e67e80', '#d699b6'],
      desc: 'Natural pine and moss forest tones designed for all-day comfort and focus.'
    },
    {
      id: 'nord',
      name: 'Nord',
      accent: '#88c0d0',
      bg: '#2e3440',
      colors: ['#2e3440', '#88c0d0', '#81a1c1', '#a3be8c', '#ebcb8b', '#bf616a'],
      desc: 'An arctic, north-bluish clean palette engineered for crystal clarity.'
    },
    {
      id: 'rose-pine',
      name: 'Rosé Pine',
      accent: '#ebbcba',
      bg: '#191724',
      colors: ['#191724', '#ebbcba', '#9ccfd8', '#f6c177', '#eb6f92', '#c4a7e7'],
      desc: 'All-natural pine, subtle lavender, and warm gold for stylish, cozy hackers.'
    },
    {
      id: 'matte-black',
      name: 'Matte Black',
      accent: '#64b5f6',
      bg: '#0d0e11',
      colors: ['#0d0e11', '#64b5f6', '#03dac6', '#ffb74d', '#cf6679', '#ba68c8'],
      desc: 'Pure stealth minimalism with deep pitch contrast and electric cyan accents.'
    }
  ];

  let currentThemeIndex = 0;

  function applyTheme(themeId) {
    const foundIndex = THEMES.findIndex(t => t.id === themeId);
    if (foundIndex !== -1) {
      currentThemeIndex = foundIndex;
    }
    const theme = THEMES[currentThemeIndex];

    if (theme.id === 'tokyo-night') {
      delete document.documentElement.dataset.theme;
    } else {
      document.documentElement.dataset.theme = theme.id;
    }

    try {
      localStorage.setItem('gnomarchy-theme', theme.id);
    } catch (e) {}

    // Update active state on buttons
    document.querySelectorAll('.theme-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.theme === theme.id);
    });

    // Update compact nav theme text
    const compactLabel = document.getElementById('currentThemeCompact');
    if (compactLabel) compactLabel.textContent = theme.name;

    // Update showcase info
    const infoName = document.getElementById('themeShowcaseName');
    const infoDesc = document.getElementById('themeShowcaseDesc');
    const infoPalette = document.getElementById('themeShowcasePalette');
    const themeCmd = document.getElementById('themeShowcaseCmd');

    if (infoName) infoName.textContent = theme.name;
    if (infoDesc) infoDesc.textContent = theme.desc;
    if (themeCmd) themeCmd.textContent = `gnomarchy theme set "${theme.id}"`;

    if (infoPalette) {
      infoPalette.innerHTML = '';
      theme.colors.forEach(col => {
        const chip = document.createElement('div');
        chip.className = 'palette-chip';
        chip.style.backgroundColor = col;
        chip.textContent = col;
        infoPalette.appendChild(chip);
      });
    }
  }

  function cycleTheme() {
    currentThemeIndex = (currentThemeIndex + 1) % THEMES.length;
    applyTheme(THEMES[currentThemeIndex].id);
  }

  // Keyboard shortcut: Press 'T' to cycle themes
  window.addEventListener('keydown', e => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    if (e.key === 't' || e.key === 'T') {
      cycleTheme();
    }
  });

  // --- Terminal Simulator ---
  const CLI_COMMANDS = {
    theme: {
      cmd: 'gnomarchy theme set "everforest"',
      output: `[gnomarchy] Switching active system theme to 'everforest'...
✔ GNOME Libadwaita accent color -> #a7c080
✔ Alacritty terminal theme updated (~/.config/alacritty/alacritty.toml)
✔ Neovim color scheme synchronized (~/.config/nvim/init.lua)
✔ btop system monitor theme updated
✔ Wallpaper set: ~/.config/gnomarchy/themes/everforest/backgrounds/default.png
✔ Dispatched lifecycle hook: ~/.config/gnomarchy/hooks/on-theme-change
Theme switch applied across all applications instantaneously.`
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
      cmd: 'gnomarchy reminder 25m "Deploy Gnomarchy website"',
      output: `[gnomarchy] Reminder scheduled!
ID:        #402
Alarm:     25 minutes from now (05:47:00)
Message:   "Deploy Gnomarchy website"
Sound:     Subtle GNOME chime enabled
Run 'gnomarchy reminder list' to manage active timers.`
    },
    voxtype: {
      cmd: 'gnomarchy voxtype toggle',
      output: `[gnomarchy] Voxtype AI speech-to-text triggered (Super + D).
✔ Audio stream capture initialized: PipeWire 48kHz
✔ Whisper offline neural model active: base.en (CPU/Vulkan)
🎙️ [LISTENING...] Speak now into your microphone...
[Voxtype] Transcribed: "The malleability of Linux combined with GNOME polish."
✔ Text automatically typed into active window at cursor.`
    },
    snapshot: {
      cmd: 'gnomarchy snapshot create "Before system refactor"',
      output: `[gnomarchy] Creating atomic Btrfs subvolume snapshot...
✔ Snapper created pre-snapshot #89
✔ Subvolumes captured: @ (root), @home, @var_log
✔ Updated Limine boot menu entries (/boot/limine.cfg)
Snapshot complete. Select '#89: Before system refactor' from boot menu to roll back anytime.`
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

  function setupTerminalSimulator() {
    const tabs = document.querySelectorAll('.terminal-tab-btn');
    const cmdEl = document.getElementById('activeTerminalCmd');
    const outEl = document.getElementById('activeTerminalOutput');
    const copyBtn = document.getElementById('copyTerminalCmdBtn');

    tabs.forEach(tab => {
      tab.addEventListener('click', () => {
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');

        const key = tab.dataset.cmdKey;
        const data = CLI_COMMANDS[key];
        if (data && cmdEl && outEl) {
          cmdEl.textContent = data.cmd;
          outEl.textContent = data.output;
        }
      });
    });

    if (copyBtn && cmdEl) {
      copyBtn.addEventListener('click', () => {
        copyToClipboard(cmdEl.textContent, copyBtn);
      });
    }
  }

  // --- Clipboard Helper ---
  function copyToClipboard(text, triggerEl) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(() => {
        showCopyFeedback(triggerEl);
      }).catch(() => {
        fallbackCopy(text, triggerEl);
      });
    } else {
      fallbackCopy(text, triggerEl);
    }
  }

  function fallbackCopy(text, triggerEl) {
    const textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.opacity = '0';
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    try {
      document.execCommand('copy');
      showCopyFeedback(triggerEl);
    } catch (err) {}
    document.body.removeChild(textArea);
  }

  function showCopyFeedback(triggerEl) {
    if (!triggerEl) return;
    const origText = triggerEl.innerHTML;
    triggerEl.innerHTML = '✔ Copied!';
    triggerEl.style.color = 'var(--color-green)';
    setTimeout(() => {
      triggerEl.innerHTML = origText;
      triggerEl.style.color = '';
    }, 2000);
  }

  // Bind all elements with data-copy-target or data-copy-text
  function setupCopyButtons() {
    document.querySelectorAll('[data-copy-text]').forEach(el => {
      el.addEventListener('click', () => {
        const text = el.getAttribute('data-copy-text');
        copyToClipboard(text, el);
      });
    });
  }

  // --- Tactile Grid Interactive Demo ---
  function setupTactileGrid() {
    const slots = document.querySelectorAll('.tactile-slot');
    const mockWindow = document.getElementById('tactileMockWindow');
    if (!slots.length || !mockWindow) return;

    slots.forEach(slot => {
      slot.addEventListener('click', () => {
        slots.forEach(s => s.classList.remove('active'));
        slot.classList.add('active');

        const col = slot.dataset.col;
        const span = slot.dataset.span;

        if (col === 'left') {
          mockWindow.style.left = '4%';
          mockWindow.style.width = '46%';
        } else if (col === 'right') {
          mockWindow.style.left = '50%';
          mockWindow.style.width = '46%';
        } else if (col === 'full') {
          mockWindow.style.left = '4%';
          mockWindow.style.width = '92%';
        } else if (col === 'center') {
          mockWindow.style.left = '16%';
          mockWindow.style.width = '68%';
        }
      });
    });
  }

  // --- Initialize on DOM ready ---
  document.addEventListener('DOMContentLoaded', () => {
    // Restore saved theme if present
    try {
      const savedTheme = localStorage.getItem('gnomarchy-theme');
      if (savedTheme) {
        applyTheme(savedTheme);
      } else {
        applyTheme('tokyo-night');
      }
    } catch (e) {
      applyTheme('tokyo-night');
    }

    // Theme buttons click
    document.querySelectorAll('.theme-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        applyTheme(btn.dataset.theme);
      });
    });

    // Header theme cycler button
    const compactBtn = document.getElementById('themeCycleBtn');
    if (compactBtn) {
      compactBtn.addEventListener('click', cycleTheme);
    }

    setupTerminalSimulator();
    setupCopyButtons();
    setupTactileGrid();
  });
})();
