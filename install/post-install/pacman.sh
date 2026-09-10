#!/bin/bash

gnomarchy_header "Cleaning Package Cache"
sudo pacman -Sc --noconfirm >/dev/null 2>&1 || true
gnomarchy_step "Package caches cleaned"
