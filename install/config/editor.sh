#!/bin/bash

gnomarchy_header "Configuring Default Editor (VS Code)"

# VS Code is the graphical default; Neovim covers the terminal.
#
# The Arch package is "code" (Code - OSS), which installs /usr/bin/code and
# code-oss.desktop. The Microsoft build from the AUR installs
# visual-studio-code.desktop instead, so both ids are handled and whichever is
# present wins.
EDITOR_DESKTOP=""
for candidate in code-oss.desktop visual-studio-code.desktop code.desktop; do
  if [[ -f "/usr/share/applications/$candidate" ]]; then
    EDITOR_DESKTOP="$candidate"
    break
  fi
done

if [[ -z "$EDITOR_DESKTOP" ]]; then
  gnomarchy_warn "No VS Code desktop entry found; leaving file associations alone."
  gnomarchy_warn "Install it with: sudo pacman -S code"
  return 0 2>/dev/null || exit 0
fi

gnomarchy_substep "Using $EDITOR_DESKTOP"

# Associate the text types a developer actually opens by double-clicking.
if command -v xdg-mime >/dev/null 2>&1; then
  for mime in \
    text/plain text/x-csrc text/x-chdr text/x-c++src text/x-c++hdr \
    text/x-python text/x-java text/x-shellscript text/markdown \
    text/css text/html text/xml application/json application/javascript \
    application/x-yaml text/x-lua text/x-go text/rust; do
    xdg-mime default "$EDITOR_DESKTOP" "$mime" 2>/dev/null || true
  done
fi

# `code --wait` is required wherever a program waits for the editor to exit;
# without it git would see an immediate return and treat the message as empty.
if [[ -x /usr/bin/code ]]; then
  sudo ln -sf /usr/bin/code /usr/local/bin/editor 2>/dev/null || true
fi

if command -v git >/dev/null 2>&1; then
  git config --global core.editor "code --wait" 2>/dev/null || true
fi

gnomarchy_step "VS Code configured as the default editor"
