#!/bin/bash

gnomarchy_header "Installing GNOME Extension Files"

# Deploys the bundled extension zips and compiles the system-wide schema
# override. This is filesystem work only: it needs no session bus, so it is
# valid during a chroot install. Enabling the extensions is a dconf write and
# happens separately, once a session exists.
if [ -f "$GNOMARCHY_INSTALL/desktop/install-extensions.py" ]; then
  python3 "$GNOMARCHY_INSTALL/desktop/install-extensions.py"
fi

gnomarchy_step "Extension files deployed and schemas compiled"
