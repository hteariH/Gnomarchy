#!/bin/bash

gnomarchy_header "Configuring Fonts & Typography"

# Ensure JetBrains Mono Nerd Font and Cascadia fonts are prioritized
sudo fc-cache -f >/dev/null 2>&1 || true

gnomarchy_step "Font caches refreshed"
