#!/bin/bash
# Replace micro with VS Code as the default editor.
#
# The Arch package is "code" (Code - OSS), which provides /usr/bin/code and
# code-oss.desktop. The Microsoft build from the AUR uses
# visual-studio-code.desktop; whichever is installed is used.
set -eEo pipefail

command -v code >/dev/null 2>&1 || sudo pacman -S --noconfirm --needed code 2>/dev/null || true

EDITOR_DESKTOP=""
for candidate in code-oss.desktop visual-studio-code.desktop code.desktop; do
  [[ -f "/usr/share/applications/$candidate" ]] && { EDITOR_DESKTOP="$candidate"; break; }
done

if [[ -z "$EDITOR_DESKTOP" ]]; then
  echo "VS Code is not installed; leaving the editor configuration alone."
  exit 0
fi

# File associations.
if command -v xdg-mime >/dev/null 2>&1; then
  for mime in text/plain text/x-csrc text/x-chdr text/x-c++src text/x-python \
    text/x-java text/x-shellscript text/markdown text/css text/html text/xml \
    application/json application/javascript application/x-yaml; do
    xdg-mime default "$EDITOR_DESKTOP" "$mime" 2>/dev/null || true
  done
fi

# git needs --wait, or it treats the commit message as empty.
command -v git >/dev/null 2>&1 &&
  git config --global core.editor "code --wait" 2>/dev/null || true

# Swap micro for VS Code in the dock, in place.
if command -v gsettings >/dev/null 2>&1; then
  FAVS="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || echo '')"
  if [[ "$FAVS" == *"micro.desktop"* ]]; then
    gsettings set org.gnome.shell favorite-apps \
      "${FAVS//micro.desktop/$EDITOR_DESKTOP}" 2>/dev/null || true
    echo "Replaced micro with $EDITOR_DESKTOP in the dock."
  fi
fi

# Remove the desktop entry Gnomarchy generated for micro; the package's own
# entry, if micro is still installed, is left alone.
rm -f "$HOME/.local/share/applications/micro.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

sudo ln -sf /usr/bin/code /usr/local/bin/editor 2>/dev/null || true

echo "VS Code is now the default editor. Open a new shell for \$EDITOR to update."
exit 0
