#!/bin/bash

gnomarchy_header "Configuring Default Text Editor (Micro)"

# Ensure micro desktop entry exists for GUI file associations
mkdir -p "$HOME/.local/share/applications"
if [ ! -f /usr/share/applications/micro.desktop ]; then
  cat <<'EOF' > "$HOME/.local/share/applications/micro.desktop"
[Desktop Entry]
Type=Application
Name=Micro
Comment=A modern and intuitive terminal-based text editor
Exec=gnome-terminal -- micro %F
Icon=text-editor
Terminal=false
Categories=Utility;TextEditor;Development;
MimeType=text/plain;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;
EOF
fi

# Set micro as the default application for plain text files
if command -v xdg-mime >/dev/null 2>&1; then
  xdg-mime default micro.desktop text/plain 2>/dev/null || true
fi

# Ensure /usr/local/bin/editor points to micro
if [ -x /usr/bin/micro ]; then
  sudo ln -sf /usr/bin/micro /usr/local/bin/editor 2>/dev/null || true
fi

gnomarchy_step "Micro configured as default text editor"
