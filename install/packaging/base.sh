#!/bin/bash

gnomarchy_header "Installing Base Gnomarchy Packages"

package_file="$GNOMARCHY_INSTALL/gnomarchy-base.packages"

# Parse packages, removing comments and blank lines
mapfile -t packages < <(grep -v '^#' "$package_file" | grep -v '^[[:space:]]*$' | tr -d '\r')

echo "Installing ${#packages[@]} core packages via pacman..."
sudo pacman -S --noconfirm --needed "${packages[@]}"

gnomarchy_step "Core packages successfully installed"
