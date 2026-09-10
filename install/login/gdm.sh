#!/bin/bash

gnomarchy_header "Configuring GDM (GNOME Display Manager)"

# Disable legacy or competing display managers if present
sudo systemctl disable sddm.service 2>/dev/null || true
sudo systemctl disable lightdm.service 2>/dev/null || true

# Copy customized GDM config
sudo mkdir -p /etc/gdm
sudo cp "$GNOMARCHY_PATH/default/gdm/custom.conf" /etc/gdm/custom.conf

# If disk is encrypted, enable seamless autologin to user session
if [[ -f /etc/crypttab ]] && grep -qv '^[[:space:]]*#' /etc/crypttab; then
  echo "Encrypted disk detected. Enabling seamless auto-login on GDM..."
  sudo sed -i "s/# AutomaticLoginEnable=true/AutomaticLoginEnable=true/" /etc/gdm/custom.conf
  sudo sed -i "s/# AutomaticLogin=@USER@/AutomaticLogin=$USER/" /etc/gdm/custom.conf
fi

# Ensure GNOME Keyring PAM integration exists
for pam_file in /etc/pam.d/gdm-password /etc/pam.d/gdm-autologin; do
  if [ -f "$pam_file" ] && ! grep -q "pam_gnome_keyring.so" "$pam_file"; then
    echo "auth     optional  pam_gnome_keyring.so" | sudo tee -a "$pam_file" >/dev/null
    echo "session  optional  pam_gnome_keyring.so auto_start" | sudo tee -a "$pam_file" >/dev/null
  fi
done

# Enable GDM systemd service
sudo systemctl enable gdm.service

gnomarchy_step "GDM configured and enabled"
