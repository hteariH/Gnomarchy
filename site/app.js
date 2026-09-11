/**
 * Gnomarchy — interactive client application
 *
 * Theme switcher, tiling-mode illustration, dictation sequence and the CLI
 * playground. Every string in CLI_ENTRIES is what the corresponding script in
 * bin/ actually prints; anything that is commentary rather than output goes in
 * the separate `note` field so the two are never confused.
 */
(function () {
  'use strict';

  // --- Themes ---------------------------------------------------------------
  const THEMES = [
    { id: 'tokyo-night', name: 'Tokyo Night' },
    { id: 'catppuccin', name: 'Catppuccin' },
    { id: 'catppuccin-latte', name: 'Catppuccin Latte' },
    { id: 'ethereal', name: 'Ethereal' },
    { id: 'everforest', name: 'Everforest' },
    { id: 'flexoki-light', name: 'Flexoki Light' },
    { id: 'gruvbox', name: 'Gruvbox' },
    { id: 'hackerman', name: 'Hackerman' },
    { id: 'kanagawa', name: 'Kanagawa' },
    { id: 'last-horizon', name: 'Last Horizon' },
    { id: 'lumon', name: 'Lumon' },
    { id: 'lupine', name: 'Lupine' },
    { id: 'matte-black', name: 'Matte Black' },
    { id: 'miasma', name: 'Miasma' },
    { id: 'nord', name: 'Nord' },
    { id: 'osaka-jade', name: 'Osaka Jade' },
    { id: 'retro-82', name: 'Retro 82' },
    { id: 'ristretto', name: 'Ristretto' },
    { id: 'rose-pine', name: 'Rosé Pine' },
    { id: 'solitude', name: 'Solitude' },
    { id: 'vantablack', name: 'Vantablack' },
    { id: 'white', name: 'White' }
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

  window.addEventListener('keydown', e => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    if (e.key === 't' || e.key === 'T') cycleTheme();
  });

  // --- Tiling mode illustration --------------------------------------------
  // Two static layouts showing what each mode does with a third window, not a
  // simulation of either extension.
  const TILING_MODES = {
    dynamic: {
      caption: 'A third window opens and the other two shrink to make room. ' +
               'You never place anything yourself.',
      panes: [
        { label: 'Alacritty', left: '2%', top: '4%', width: '47%', height: '92%' },
        { label: 'Brave', left: '51%', top: '4%', width: '47%', height: '44%' },
        { label: 'nvim', left: '51%', top: '52%', width: '47%', height: '44%', isNew: true }
      ]
    },
    manual: {
      caption: 'The third window opens floating, wherever GNOME puts it. ' +
               'Super + T and a letter drops it into a grid zone when you decide to.',
      panes: [
        { label: 'Alacritty', left: '2%', top: '4%', width: '47%', height: '92%' },
        { label: 'Brave', left: '51%', top: '4%', width: '47%', height: '92%' },
        { label: 'nvim', left: '27%', top: '24%', width: '46%', height: '52%', isNew: true }
      ]
    }
  };

  function renderTiling(mode) {
    const spec = TILING_MODES[mode];
    const stage = document.getElementById('tilingPanes');
    const caption = document.getElementById('tilingCaption');
    if (!spec || !stage) return;

    if (caption) caption.textContent = spec.caption;

    stage.innerHTML = '';
    spec.panes.forEach(p => {
      const el = document.createElement('div');
      el.className = 'tiling-pane' + (p.isNew ? ' is-new' : '');
      el.style.left = p.left;
      el.style.top = p.top;
      el.style.width = p.width;
      el.style.height = p.height;
      el.textContent = p.label;
      stage.appendChild(el);
    });
  }

  function setupTiling() {
    const buttons = document.querySelectorAll('[data-tiling-mode]');
    if (!buttons.length) return;

    buttons.forEach(btn => {
      btn.addEventListener('click', () => {
        buttons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        renderTiling(btn.dataset.tilingMode);
      });
    });

    renderTiling('dynamic');
  }

  // --- Dictation sequence ---------------------------------------------------
  function setupVoxtypeSequence() {
    const btn = document.getElementById('simulateVoiceBtn');
    const statusLabel = document.getElementById('voiceStatusLabel');
    const transcript = document.getElementById('voiceTranscript');
    const bars = document.querySelectorAll('#audioWaveVisualizer .audio-bar');
    if (!btn) return;

    let running = false;

    btn.addEventListener('click', () => {
      if (running) return;
      running = true;

      if (statusLabel) {
        statusLabel.textContent = 'RECORDING';
        statusLabel.style.color = 'var(--accent)';
      }
      if (transcript) transcript.textContent = 'Recording. Press Super+D again to stop.';

      let count = 0;
      const interval = setInterval(() => {
        bars.forEach(bar => {
          bar.style.height = `${Math.floor(Math.random() * 42) + 8}px`;
        });
        count++;

        if (count > 16) {
          clearInterval(interval);
          bars.forEach((bar, i) => {
            const heights = [14, 24, 36, 48, 28, 18, 40, 30, 12];
            bar.style.height = `${heights[i % heights.length]}px`;
          });

          if (statusLabel) {
            statusLabel.textContent = 'TRANSCRIBING (whisper-cpp, CPU)';
            statusLabel.style.color = 'var(--text-muted)';
          }
          if (transcript) transcript.textContent = 'Running whisper-cpp on the recording...';

          setTimeout(() => {
            if (statusLabel) {
              statusLabel.textContent = 'TYPED INTO THE FOCUSED WINDOW';
              statusLabel.style.color = 'var(--color-green)';
            }
            if (transcript) {
              transcript.textContent =
                '"Roll back to the snapshot from before the kernel upgrade."';
            }
            running = false;
          }, 900);
        }
      }, 100);
    });
  }

  // --- CLI playground -------------------------------------------------------
  // `output` is verbatim; `note` is this site talking, not the script.
  const CLI_ENTRIES = {
    theme: {
      cmd: 'gnomarchy theme set nord',
      output: 'Applied theme: nord',
      note: 'Terse on purpose. The palette reaches Alacritty, GNOME Terminal, ' +
            'GTK 3 and 4, Neovim, btop, the GNOME accent and the wallpaper — ' +
            'all generated from the theme’s alacritty.toml.'
    },
    tiling: {
      cmd: 'gnomarchy tiling enable',
      output: `Enabling dynamic tiling (Forge)
  Dynamic tiling enabled

  Super + h/j/k/l           focus window left/down/up/right
  Super + Shift + h/j/k/l   move window within the tree
  Super + Ctrl + h/j/k/l    swap window with its neighbour
  Super + G                 flip the split direction
  Super + Alt + T           tiling on or off, without disabling it

  Super + / now opens the keybindings and Super + Shift + / the manual.
  Log out and back in to load the change (Wayland cannot restart the shell in place).`,
      note: 'Enabling one mode disables the other. With both extensions live ' +
            'they fight over window placement.'
    },
    snapshot: {
      cmd: 'gnomarchy snapshot create "Before the kernel upgrade"',
      output: `Creating Snapper root snapshot: Before the kernel upgrade
Snapshot created successfully.`,
      note: 'Snapper is configured on root, with timeline and cleanup timers and ' +
            'a retention limit of 10. Roll back with snapper rollback and a ' +
            'reboot — limine does not currently list snapshots as boot entries. ' +
            '/home is a separate subvolume and is not part of a root snapshot.'
    },
    webapp: {
      cmd: 'gnomarchy webapp add Claude https://claude.ai',
      output: `Fetching icon for claude.ai...
✓ Web application 'Claude' created successfully!
  Location: /home/you/.local/share/applications/gnomarchy-webapp-claude.desktop
  URL:      https://claude.ai`,
      note: 'The app gets its own browser profile under ' +
            '~/.local/share/gnomarchy/webapps/claude/profile and is appended to ' +
            'the GNOME favourites, which is what the dock reads.'
    },
    keymap: {
      cmd: 'gnomarchy keymap status',
      output: `Keyboard layout: gnome

  Super + Return            terminal
  Super + B                 browser
  Super + E                 file manager
  Super + Alt + Space       Gnomarchy menu
  Super + Escape            screensaver
  Super + K                 searchable keybindings
  Super + Shift + K         the manual
  Super + T                 cycle the zone layout (manual tiling)

  Super + W                 close window
  Super + Up                maximize
  Super + 1..6              switch to workspace 1..6
  Super + Shift + 1..6      move window to workspace

Switch with: gnomarchy keymap <omarchy|gnome>`,
      note: 'gnomarchy keybindings goes further and reads the bindings back out ' +
            'of dconf, so it shows what is really set rather than what was ' +
            'intended.'
    },
    update: {
      cmd: 'gnomarchy update',
      output: `==> Updating Gnomarchy System Packages
==> Updating Gnomarchy Configurations
    Configuration updated
==> Applying pending migrations
    2026-09-11-1500-bind-keybindings-and-manual.sh

✓ System up to date!`,
      note: 'No set -e here on purpose: each stage may fail on its own and is ' +
            'recorded. An earlier version swallowed every failure and printed ' +
            'success regardless, which hid a broken git pull for weeks.'
    },
    windows: {
      cmd: 'gnomarchy windows info',
      output: `Windows 11 VM Configuration:
  Location: /home/you/.local/share/gnomarchy/vms/windows-11
  RAM:      8 GB
  CPUs:     4 Cores (Host Passthrough)
  Disk:     VirtIO SCSI / QCOW2
  Graphics: VirtIO GPU (OpenGL Accelerated)
  TPM:      Software TPM 2.0 (swtpm)`,
      note: 'You supply the Windows ISO. It opens in an ordinary QEMU window — ' +
            'there is no seamless mode, no shared clipboard and no shared folder.'
    }
  };

  function setupCliPlayground() {
    const tabs = document.querySelectorAll('.cli-tab');
    const cmdDisplay = document.getElementById('cliCmdDisplay');
    const outDisplay = document.getElementById('cliOutputDisplay');
    const noteDisplay = document.getElementById('cliNoteDisplay');
    const copyBtn = document.getElementById('cliCopyBtn');

    function show(key) {
      const entry = CLI_ENTRIES[key];
      if (!entry || !cmdDisplay || !outDisplay) return;
      cmdDisplay.textContent = entry.cmd;
      outDisplay.textContent = entry.output;
      if (noteDisplay) {
        noteDisplay.textContent = entry.note || '';
        noteDisplay.hidden = !entry.note;
      }
    }

    tabs.forEach(tab => {
      tab.addEventListener('click', () => {
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        show(tab.dataset.cmd);
      });
    });

    show('theme');

    if (copyBtn && cmdDisplay) {
      copyBtn.addEventListener('click', () => copyText(cmdDisplay.textContent, copyBtn));
    }
  }

  // --- Copy helper ----------------------------------------------------------
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

  // --- Init -----------------------------------------------------------------
  document.addEventListener('DOMContentLoaded', () => {
    try {
      applyTheme(localStorage.getItem('gnomarchy-theme') || 'tokyo-night');
    } catch (e) {
      applyTheme('tokyo-night');
    }

    document.querySelectorAll('[data-theme-target]').forEach(btn => {
      btn.addEventListener('click', () => applyTheme(btn.dataset.themeTarget));
    });

    const navToggle = document.getElementById('navThemeToggleBtn');
    if (navToggle) navToggle.addEventListener('click', cycleTheme);

    document.querySelectorAll('[data-copy-cmd]').forEach(el => {
      el.addEventListener('click', () => copyText(el.getAttribute('data-copy-cmd'), el));
    });

    setupTiling();
    setupVoxtypeSequence();
    setupCliPlayground();
  });
})();
