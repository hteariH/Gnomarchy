/**
 * Gnomarchy — Interactive Client Application
 * Theme cycling, clipboard helpers & keyboard interactions matching Omarchy.org
 */

(function () {
  'use strict';

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

    // Update active state on slash buttons
    document.querySelectorAll('.theme-btn-slash').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.theme === theme.id);
    });

    // Update preview labels if present
    const nameEl = document.getElementById('themeDisplayName');
    const cmdEl = document.getElementById('themeCmdActive');
    if (nameEl) nameEl.textContent = theme.name;
    if (cmdEl) cmdEl.textContent = theme.id;
  }

  function cycleTheme() {
    currentThemeIndex = (currentThemeIndex + 1) % THEMES.length;
    applyTheme(THEMES[currentThemeIndex].id);
  }

  // Keyboard shortcut: Press 'T' to cycle themes anywhere
  window.addEventListener('keydown', e => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    if (e.key === 't' || e.key === 'T') {
      cycleTheme();
    }
  });

  // Copy helper
  function copyText(text, triggerEl) {
    const handleSuccess = () => {
      const orig = triggerEl.textContent;
      triggerEl.textContent = 'Copied!';
      setTimeout(() => { triggerEl.textContent = orig; }, 1500);
    };

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(handleSuccess).catch(() => fallbackCopy(text, handleSuccess));
    } else {
      fallbackCopy(text, handleSuccess);
    }
  }

  function fallbackCopy(text, cb) {
    const el = document.createElement('textarea');
    el.value = text;
    el.style.position = 'fixed';
    el.style.opacity = '0';
    document.body.appendChild(el);
    el.focus();
    el.select();
    try {
      document.execCommand('copy');
      if (cb) cb();
    } catch (err) {}
    document.body.removeChild(el);
  }

  document.addEventListener('DOMContentLoaded', () => {
    // Restore saved theme
    try {
      const saved = localStorage.getItem('gnomarchy-theme') || 'tokyo-night';
      applyTheme(saved);
    } catch (e) {
      applyTheme('tokyo-night');
    }

    // Slash theme button clicks
    document.querySelectorAll('.theme-btn-slash[data-theme]').forEach(btn => {
      btn.addEventListener('click', () => {
        applyTheme(btn.dataset.theme);
      });
    });

    // Header theme cycler button
    const navBtn = document.getElementById('navThemeToggleBtn');
    if (navBtn) {
      navBtn.addEventListener('click', cycleTheme);
    }

    // Copy buttons
    document.querySelectorAll('[data-copy-cmd]').forEach(btn => {
      btn.addEventListener('click', () => {
        const text = btn.getAttribute('data-copy-cmd');
        copyText(text, btn);
      });
    });
  });
})();
