/**
 * Gnomarchy — interactive client application
 *
 * Theme switcher, dictation sequence and the CLI
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
      note: 'Terse on purpose. The palette reaches GNOME Terminal, ' +
            'GTK 3 and 4, Neovim, btop, the GNOME accent and the wallpaper — ' +
            'all generated from the theme’s alacritty.toml.'
    },
    tiling: {
      cmd: 'gnomarchy tiling status',
      output: `Tiling: on (Tiling Shell)
  auto-placement: false (Gnomarchy keeps it off)
  Ctrl + drag to pick a zone, Super+Shift+arrows to throw a window
  shell state:    ACTIVE

Switch with: gnomarchy tiling <enable|disable>`,
      note: 'shell state is the shell’s own answer, not dconf’s: an ' +
            'extension built for an older GNOME is enabled and does nothing.'
    },
    snapshot: {
      cmd: 'gnomarchy snapshot create "Before the kernel upgrade"',
      output: `Creating Snapper root snapshot: Before the kernel upgrade
Snapshot created successfully.`,
      note: 'Snapper snapshots the root before and after every pacman transaction. ' +
            'Each snapshot appears in the Limine menu and boots with its own kernel; ' +
            'gnomarchy snapshot restore makes one the system. /home is a separate ' +
            'subvolume and is not part of a root snapshot.'
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
==> Updating Boot Tooling
    Boot menu regenerated

✓ System up to date!`,
      note: 'No set -e here on purpose: each stage may fail on its own and is ' +
            'recorded. An earlier version swallowed every failure and printed ' +
            'success regardless, which hid a broken git pull for weeks.'
    },
    windows: {
      cmd: 'gnomarchy windows status',
      output: `WinBoat:
  no    not installed (gnomarchy windows install)
Requirements:
  ok    KVM: /dev/kvm is usable
  ok    Docker: the service is running
  ok    Docker: compose is available
  ok    Docker: you is in the docker group
  ok    FreeRDP: xfreerdp3 is installed`,
      note: 'Opt-in. gnomarchy windows install takes winboat-bin from the AUR, or the ' +
            'checksum-pinned release AppImage; WinBoat then runs Windows in a ' +
            'container and opens its apps as ordinary windows.'
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

    setupVoxtypeSequence();
    setupCliPlayground();
  });
})();
