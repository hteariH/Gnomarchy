#!/bin/bash
# Theme palette for the Limine menu.
#
# A theme's alacritty.toml is the canonical palette (CLAUDE.md, The theme
# engine). This turns it into the KEY=rrggbb lines of
# /etc/gnomarchy/boot-theme.conf, which gnomarchy-boot reads. Sourced by
# gnomarchy-theme-set as the user, so it depends on nothing else here.

# boot_palette_from_alacritty FILE — prints BACKGROUND, FOREGROUND, ACCENT,
# NORMAL_0..7 and BRIGHT_0..7, or fails naming the first missing colour.
boot_palette_from_alacritty() {
  local file="$1" section="" line key i
  local re_colour='^[[:space:]]*([a-z]+)[[:space:]]*=[[:space:]]*"#?([0-9a-fA-F]{6})"'
  local names=(black red green yellow blue magenta cyan white)
  local -A colour=()

  if [[ ! -f "$file" ]]; then
    printf 'palette: no such file: %s\n' "$file" >&2
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ "$line" =~ ^\[colors\.(primary|normal|bright)\] ]]; then
      section="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\[ ]]; then
      section=""
    elif [[ -n "$section" && "$line" =~ $re_colour ]]; then
      colour["$section.${BASH_REMATCH[1]}"]="${BASH_REMATCH[2],,}"
    fi
  done <"$file"

  for key in primary.background primary.foreground; do
    if [[ -z "${colour[$key]:-}" ]]; then
      printf 'palette: %s has no %s\n' "$file" "$key" >&2
      return 1
    fi
  done
  for i in "${!names[@]}"; do
    for key in "normal.${names[i]}" "bright.${names[i]}"; do
      if [[ -z "${colour[$key]:-}" ]]; then
        printf 'palette: %s has no %s\n' "$file" "$key" >&2
        return 1
      fi
    done
  done

  printf 'BACKGROUND=%s\n' "${colour[primary.background]}"
  printf 'FOREGROUND=%s\n' "${colour[primary.foreground]}"
  printf 'ACCENT=%s\n' "${colour[normal.blue]}"
  for i in "${!names[@]}"; do
    printf 'NORMAL_%d=%s\n' "$i" "${colour[normal.${names[i]}]}"
  done
  for i in "${!names[@]}"; do
    printf 'BRIGHT_%d=%s\n' "$i" "${colour[bright.${names[i]}]}"
  done
}
