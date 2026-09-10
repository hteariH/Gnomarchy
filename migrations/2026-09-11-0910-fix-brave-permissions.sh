#!/bin/bash
# Brave was extracted with zipfile.extractall(), which drops Unix modes, and
# only the main binary was made executable. Every helper stayed 0644, so the
# browser died at startup:
#   FATAL spawn /opt/brave-origin/chrome_crashpad_handler: Permission denied
set -eEo pipefail

BRAVE_DIR="/opt/brave-origin"
[[ -d "$BRAVE_DIR" ]] || exit 0

fixed=0
while IFS= read -r -d '' file; do
  # Restore the bit on real binaries only, never on data files.
  if [[ "$(head -c 4 "$file" 2>/dev/null)" == $'\x7fELF' ]] && [[ ! -x "$file" ]]; then
    sudo chmod 755 "$file" && fixed=$((fixed + 1))
  fi
done < <(sudo find "$BRAVE_DIR" -type f -print0 2>/dev/null)

# Chromium refuses to start its sandbox unless this is setuid root.
if [[ -f "$BRAVE_DIR/chrome-sandbox" ]]; then
  sudo chown root:root "$BRAVE_DIR/chrome-sandbox" 2>/dev/null || true
  sudo chmod 4755 "$BRAVE_DIR/chrome-sandbox" 2>/dev/null || true
fi

((fixed > 0)) && echo "Restored the executable bit on $fixed Brave binary/binaries."
exit 0
