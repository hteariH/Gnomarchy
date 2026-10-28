#!/bin/bash
# Chromium, OBS Studio, LibreOffice, Obsidian, Spotify, mise and Claude Code.
#
# They sat in install/gnomarchy-other.packages, which nothing ever read, so no
# machine got them. They are now in gnomarchy-base.packages (Claude Code from
# its own installer); this brings an installed machine level with a new one.
#
# Idempotent: --needed skips what is installed, and Claude Code is installed
# only when missing.
set -eEo pipefail

sudo pacman -S --needed --noconfirm \
  chromium obs-studio libreoffice-fresh obsidian spotify-launcher mise

if ! command -v claude >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/claude" ]]; then
  curl -fsSL https://claude.ai/install.sh | bash
fi
