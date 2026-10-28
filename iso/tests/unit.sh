#!/bin/bash
# Runs every fast test and shellcheck. Needs an Arch userland; CI runs it in
# archlinux:latest, and so can you, from the repository root:
#
#   docker run --rm -v "$PWD:/w" -w /w archlinux:latest bash iso/tests/unit.sh --deps
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

if [[ "${1:-}" == --deps ]]; then
  pacman -Sy --noconfirm --needed kbd xkeyboard-config tzdata shellcheck diffutils >/dev/null || exit 1
fi

rc=0
for t in iso/tests/test-*.sh; do
  echo "=== $t"
  bash "$t" || rc=1
done

echo "=== shellcheck"
# Entry points only: -x follows their `source` lines and checks each library
# in the context that defines its variables. Checked alone, a library reports
# every path from common.sh as unassigned.
mapfile -t scripts < <(
  printf '%s\n' \
    default/boot/gnomarchy-boot default/boot/50-gnomarchy-boot default/boot/deploy.sh \
    default/boot/initcpio-post \
    iso/installer/gnomarchy-install iso/installer/lib/run-stage.sh \
    bin/gnomarchy-snapshot-restore bin/gnomarchy-snapshot-notify bin/gnomarchy-windows \
    install/login/boot.sh install/desktop/set-keyboard-layout.sh \
    iso/tests/test-*.sh |
    while read -r f; do [[ -f "$f" ]] && printf '%s\n' "$f"; done
)
shellcheck -x -S warning "${scripts[@]}" || rc=1

exit "$rc"
