#!/bin/bash
# Assertions for the fast tests. A test script sources this, makes its checks
# and ends with t_done, whose status becomes the script's.

t_pass=0
t_fail=0

t_ok() {
  printf '  PASS  %s\n' "$1"
  t_pass=$((t_pass + 1))
}

t_no() {
  printf '  FAIL  %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" | sed 's/^/        /'
  fi
  t_fail=$((t_fail + 1))
}

# t_eq LABEL ACTUAL EXPECTED
t_eq() {
  if [[ "$2" == "$3" ]]; then
    t_ok "$1"
  else
    t_no "$1" "expected: $3"$'\n'"actual:   $2"
  fi
}

# t_true LABEL COMMAND... passes when the command succeeds.
t_true() {
  local label="$1"
  shift
  if "$@"; then t_ok "$label"; else t_no "$label" "command failed: $*"; fi
}

# t_false LABEL COMMAND... passes when the command fails.
t_false() {
  local label="$1"
  shift
  if "$@"; then t_no "$label" "command unexpectedly succeeded: $*"; else t_ok "$label"; fi
}

# t_golden LABEL ACTUAL_FILE GOLDEN_FILE
# GNOMARCHY_UPDATE_GOLDEN=1 rewrites the golden file instead of comparing; read
# the diff before committing one.
t_golden() {
  local label="$1" actual="$2" golden="$3"
  if [[ "${GNOMARCHY_UPDATE_GOLDEN:-}" == 1 ]]; then
    cp "$actual" "$golden"
    t_ok "$label (golden updated)"
  elif diff -u "$golden" "$actual" >/dev/null; then
    t_ok "$label"
  else
    t_no "$label" "$(diff -u "$golden" "$actual")"
  fi
}

t_done() {
  printf '\n  %d passed, %d failed\n' "$t_pass" "$t_fail"
  ((t_fail == 0))
}
