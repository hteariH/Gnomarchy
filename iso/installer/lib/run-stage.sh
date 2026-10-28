#!/bin/bash
# run-stage.sh LIBDIR FUNCTION — runs one installation stage in this fresh bash
# process. gnomarchy-install starts it rather than calling the function in a
# subshell: errexit is off inside anything called as an operand of if, ! or ||,
# and a subshell inherits that, so a stage could run on past a failure.
# The globals a stage reads arrive in the environment (exported by main).
# shellcheck source-path=SCRIPTDIR
set -Eeuo pipefail
trap 'echo "stage failed: $BASH_COMMAND (line $LINENO, status $?)"' ERR

# The passwords arrive in the environment; keep them as shell variables only,
# so no child (pacstrap, arch-chroot, install.sh and what it runs) inherits them.
export -n PASSWORD DISK_PASSWORD

libdir="$1"
fn="$2"
# shellcheck source=form.sh
source "$libdir/form.sh"
# shellcheck source=disk.sh
source "$libdir/disk.sh"
# shellcheck source=stages.sh
source "$libdir/stages.sh"
"$fn"
