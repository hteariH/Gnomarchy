#!/bin/bash
# run_stage must stop a stage at its first failing command, whatever context
# the caller is in, and report the failure without aborting the installer.
set -u
cd "$(dirname "$0")/../.." || exit 1
# shellcheck source=iso/tests/lib/assert.sh
source iso/tests/lib/assert.sh

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The installer's functions, without running main.
# shellcheck source=iso/installer/gnomarchy-install
source iso/installer/gnomarchy-install
set +eE

# A copy of the library directory with stages of our own.
mkdir "$work/lib"
cp iso/installer/lib/*.sh "$work/lib/"
cat >"$work/lib/stages.sh" <<'STAGES'
STAGE_FNS=(stage_fails stage_passes stage_uses_global)
STAGE_TITLES=("Fails" "Passes" "Uses a global")
stage_fails() { echo one; false; echo notreached; }
stage_passes() { echo fine; }
stage_uses_global() { echo "disk=$DISK"; }
STAGES
# shellcheck source=/dev/null
source "$work/lib/stages.sh"

INSTALLER_DIR="$work"
LOG="$work/installer.log"
UNATTENDED=1
STAGE_STATE=(wait wait wait)
export LOG UNATTENDED
export DISK=/dev/test

yesno() { if "$@"; then echo yes; else echo no; fi; }

: >"$LOG"
# Called as main calls it: a plain statement, then the status.
run_stage 0 >/dev/null
t_eq "a failing stage reports a non-zero status" "$(yesno test "$STAGE_RC" -ne 0)" yes
t_eq "the stage ran up to the failure" "$(grep -c '^one$' "$LOG")" 1
t_eq "nothing ran after the failure" "$(grep -c notreached "$LOG")" 0
t_eq "the failing command is named in the log" "$(grep -c '^stage failed: false' "$LOG")" 1

# Through a || condition, the context that disables errexit in a function.
: >"$LOG"
STAGE_RC=0
run_stage 0 >/dev/null || true
t_eq "still fails when run_stage is an operand of ||" "$(yesno test "$STAGE_RC" -ne 0)" yes
t_eq "and still stops there" "$(grep -c notreached "$LOG")" 0

: >"$LOG"
run_stage 1 >/dev/null
t_eq "a passing stage reports 0" "$STAGE_RC" 0

: >"$LOG"
run_stage 2 >/dev/null
t_eq "exported globals reach the stage" "$(grep -c '^disk=/dev/test$' "$LOG")" 1

t_done
