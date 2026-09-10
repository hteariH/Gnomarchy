#!/bin/bash

gnomarchy_header "Configuring Flatpak & Installing Bazaar App Store"

if command -v flatpak >/dev/null 2>&1; then
  # 1. Enable Flathub Remote system-wide
  echo "Enabling Flathub repository..."
  sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
  flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

  # 2. Attempt immediate install if not in chroot
  if [[ -z "$GNOMARCHY_CHROOT_INSTALL" ]]; then
    echo "Installing Bazaar (Flatpak App Store)..."
    flatpak install -y --noninteractive flathub io.github.kolunmi.Bazaar 2>/dev/null || true
    echo "Installing LocalSend..."
    flatpak install -y --noninteractive flathub org.localsend.localsend_app 2>/dev/null || true
  fi

  # 3. Create first-boot background app installer service for reliable desktop session install
  sudo tee /usr/local/bin/gnomarchy-firstboot >/dev/null <<'FIRSTBOOT_EOF'
#!/bin/bash
# Gnomarchy First-Boot App Setup
MARKER="$HOME/.config/gnomarchy/.firstboot-done"
if [ -f "$MARKER" ]; then
  exit 0
fi

# Wait for network connectivity
for i in {1..20}; do
  if ping -c 1 1.1.1.1 >/dev/null 2>&1 || curl -sI https://flathub.org >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Ensure Flathub is ready
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

# Install Bazaar App Store
if ! flatpak list --app 2>/dev/null | grep -q "io.github.kolunmi.Bazaar"; then
  flatpak install -y --noninteractive flathub io.github.kolunmi.Bazaar 2>/dev/null || true
fi

# Install LocalSend
if ! flatpak list --app 2>/dev/null | grep -q "org.localsend.localsend_app"; then
  flatpak install -y --noninteractive flathub org.localsend.localsend_app 2>/dev/null || true
fi

# Fallback: Install Brave Browser via Flatpak if native binary is missing
if ! command -v brave-origin >/dev/null 2>&1 && ! command -v brave >/dev/null 2>&1; then
  flatpak install -y --noninteractive flathub com.brave.Browser 2>/dev/null || true
fi

# Mark completed
mkdir -p "$HOME/.config/gnomarchy"
touch "$MARKER"

if command -v notify-send >/dev/null 2>&1; then
  notify-send "Gnomarchy Initialized" "Bazaar App Store and essential apps are ready." 2>/dev/null || true
fi
FIRSTBOOT_EOF

  sudo chmod +x /usr/local/bin/gnomarchy-firstboot 2>/dev/null || true

  # 4. Create XDG Autostart entry so it executes upon first user login
  sudo mkdir -p /etc/xdg/autostart
  sudo tee /etc/xdg/autostart/gnomarchy-firstboot.desktop >/dev/null <<'AUTOSTART_EOF'
[Desktop Entry]
Type=Application
Name=Gnomarchy First Boot Setup
Exec=/usr/local/bin/gnomarchy-firstboot
Terminal=false
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
AUTOSTART_EOF

  gnomarchy_step "Flatpak, Bazaar, and First-Boot setup configured"
else
  gnomarchy_warn "Flatpak is not installed. Skipping Flatpak configuration."
fi
