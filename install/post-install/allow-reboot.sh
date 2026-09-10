#!/bin/bash

# Remove temporary installer passwordless sudoers rules
sudo rm -f /etc/sudoers.d/99-gnomarchy-installer 2>/dev/null || true
sudo rm -f /etc/sudoers.d/99-omarchy-installer 2>/dev/null || true

# Signal completion for archiso / automated scripts
sudo touch /var/tmp/gnomarchy-install-completed 2>/dev/null || true
