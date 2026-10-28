#!/bin/bash
# Every bundled theme must yield a complete Limine palette.
set -u
cd "$(dirname "$0")/../.." || exit 1
# shellcheck source=iso/tests/lib/assert.sh
source iso/tests/lib/assert.sh
# shellcheck source=default/boot/lib/palette.sh
source default/boot/lib/palette.sh

out="$(boot_palette_from_alacritty themes/tokyo-night/alacritty.toml)"
t_eq "tokyo-night background" "$(sed -n 's/^BACKGROUND=//p' <<<"$out")" "1a1b26"
t_eq "tokyo-night foreground" "$(sed -n 's/^FOREGROUND=//p' <<<"$out")" "c0caf5"
t_eq "the accent is the normal blue" "$(sed -n 's/^ACCENT=//p' <<<"$out")" "7aa2f7"
t_eq "normal black is NORMAL_0" "$(sed -n 's/^NORMAL_0=//p' <<<"$out")" "15161e"
t_eq "bright white is BRIGHT_7" "$(sed -n 's/^BRIGHT_7=//p' <<<"$out")" "c0caf5"

for theme in themes/*/; do
  name="$(basename "$theme")"
  if out="$(boot_palette_from_alacritty "${theme}alacritty.toml" 2>&1)" &&
    [[ "$(grep -cE '^[A-Z0-9_]+=[0-9a-f]{6}$' <<<"$out")" == 19 ]]; then
    t_ok "$name yields 19 palette values"
  else
    t_no "$name does not yield a full palette" "$out"
  fi
done

tmp="$(mktemp)"
printf '[colors.primary]\nbackground = "#000000"\n' >"$tmp"
err="$(boot_palette_from_alacritty "$tmp" 2>&1)" && t_no "a palette with missing colours is rejected" || t_ok "a palette with missing colours is rejected"
t_true "the error names the missing colour" grep -q "no primary.foreground" <<<"$err"
rm -f "$tmp"

t_done
