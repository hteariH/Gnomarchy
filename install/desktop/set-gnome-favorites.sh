#!/bin/bash

gnomarchy_header "Configuring Dock Favorites"

# Favorites must be computed from what is actually installed, not guessed.
#
# The previous static list named three possible Brave desktop IDs so that at
# least one would match. When more than one exists -- and the Brave Origin
# installer writes both brave-origin.desktop and brave-browser.desktop -- the
# dash shows a duplicate icon for the same browser.

desktop_exists() {
  local id="$1"
  [[ -f "/usr/share/applications/$id" ]] ||
    [[ -f "$HOME/.local/share/applications/$id" ]] ||
    [[ -f "/var/lib/flatpak/exports/share/applications/$id" ]] ||
    [[ -f "$HOME/.local/share/flatpak/exports/share/applications/$id" ]]
}

# Append the first candidate that exists, so each application appears once.
favorites=()
add_first_available() {
  local id
  for id in "$@"; do
    if desktop_exists "$id"; then
      favorites+=("$id")
      return 0
    fi
  done
  return 0
}

add_first_available \
  "brave-origin.desktop" \
  "brave-browser-origin.desktop" \
  "brave-browser.desktop" \
  "com.brave.Browser.desktop" \
  "chromium.desktop"

add_first_available "org.gnome.Terminal.desktop" "alacritty.desktop"
add_first_available "org.gnome.Nautilus.desktop"
add_first_available "micro.desktop"
add_first_available "io.github.kolunmi.Bazaar.desktop"
add_first_available "org.gnome.Settings.desktop"

if ((${#favorites[@]} == 0)); then
  gnomarchy_warn "No known applications found; leaving dock favorites untouched."
  return 0 2>/dev/null || exit 0
fi

quoted=()
for fav in "${favorites[@]}"; do
  quoted+=("'$fav'")
done
list="$(IFS=,; echo "${quoted[*]}")"

gsettings set org.gnome.shell favorite-apps "[$list]" 2>/dev/null || true

for fav in "${favorites[@]}"; do
  gnomarchy_substep "$fav"
done

gnomarchy_step "Dock favorites set (${#favorites[@]} apps)"
