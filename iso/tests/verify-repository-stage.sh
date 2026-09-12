#!/bin/bash

# Exercises install/config/repository.sh against a real git remote.
#
# That stage turns the rsynced installation into a git repository so
# `gnomarchy update` can pull. To do it, it fetches a commit, aligns the index
# to it, and then enforces that index with `git clean -fd` and
# `git checkout -- .`.
#
# It used to fetch `main` unconditionally. On an image built from anything else
# that combination deleted every file main did not have and reverted every file
# the branch changed -- including the installer's own scripts, while bash was
# still reading them. The smoke test therefore verified main rather than the
# branch under test, and one run hung for 100 minutes when all.sh was rewritten
# underneath it and the next stage it sourced no longer existed.
#
# Nothing in the ISO test suite could catch that: it only ever inspects the
# finished image, by which point the substitution has already happened and
# looks like a correct install of main. Hence this test.
#
# Usage: verify-repository-stage.sh [path-to-repo]   (defaults to this checkout)
set -uo pipefail

REPO_SRC="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"
LAB="$(mktemp -d)"
trap 'rm -rf "$LAB"' EXIT

pass=0
fail=0
ok() {
  printf '  \033[0;32mPASS\033[0m  %s\n' "$1"
  pass=$((pass + 1))
}
no() {
  printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"
  fail=$((fail + 1))
}

# The stage calls these; it is not what is under test here.
gnomarchy_header() { :; }
gnomarchy_step() { :; }
gnomarchy_substep() { :; }
gnomarchy_warn() { :; }

# --- a remote with main and a feature branch -------------------------------
REMOTE="$LAB/remote.git"
WORK="$LAB/work"

git init -q "$WORK"
git -C "$WORK" config core.autocrlf false
git -C "$WORK" config user.email test@gnomarchy.local
git -C "$WORK" config user.name "Gnomarchy Test"

mkdir -p "$WORK/install" "$WORK/bin"
echo "main version" >"$WORK/bin/cmd"
echo "shared" >"$WORK/keepme"
git -C "$WORK" add -A
git -C "$WORK" commit -qm "main"
git -C "$WORK" branch -M main

git init -q --bare "$REMOTE"
git -C "$WORK" remote add origin "$REMOTE"
git -C "$WORK" push -q origin main

git -C "$WORK" checkout -q -b feature
echo "branch version" >"$WORK/bin/cmd"
mkdir -p "$WORK/gui/src"
echo "gui code" >"$WORK/gui/src/main.js"
echo "new stage" >"$WORK/install/control-center.sh"
git -C "$WORK" add -A
git -C "$WORK" commit -qm "feature"
git -C "$WORK" push -q origin feature

BRANCH_SHA="$(git -C "$WORK" rev-parse HEAD)"
MAIN_SHA="$(git -C "$WORK" rev-parse main)"

# --- deploy the way the ISO does: the tree, without .git -------------------
deploy() {
  local ref="$1" recorded="$2" dest="$LAB/target"
  rm -rf "$dest"
  mkdir -p "$dest"
  git -C "$WORK" archive "$ref" | tar -x -C "$dest"
  mkdir -p "$dest/install"
  [[ -n "$recorded" ]] && printf '%s\n' "$recorded" >"$dest/install/.build-commit"
  printf '%s' "$dest"
}

run_stage() {
  export GNOMARCHY_PATH="$1"
  export GNOMARCHY_INSTALL="$1/install"
  export GNOMARCHY_REPO_URL="$REMOTE"
  # shellcheck disable=SC1091
  source "$REPO_SRC/install/config/repository.sh" >/dev/null 2>&1
}

echo "=== repository stage ==="

echo "-- image built from main (what a release does)"
T="$(deploy main "$MAIN_SHA")"
run_stage "$T"
[[ "$(cat "$T/bin/cmd")" == "main version" ]] && ok "content preserved" || no "content changed"
[[ -d "$T/.git" ]] && ok "repository created" || no "no repository created"
git -C "$T" rev-parse --verify -q refs/remotes/origin/main >/dev/null &&
  ok "origin/main tracked, so gnomarchy update can pull" ||
  no "origin/main missing, gnomarchy update would not work"

echo "-- image built from a branch that is on the remote (what CI does)"
T="$(deploy feature "$BRANCH_SHA")"
run_stage "$T"
[[ -f "$T/gui/src/main.js" ]] && ok "files only the branch has survive" || no "branch-only files were deleted"
[[ -f "$T/install/control-center.sh" ]] && ok "install stages only the branch has survive" || no "branch-only stage deleted"
[[ "$(cat "$T/bin/cmd")" == "branch version" ]] && ok "branch edits survive" || no "branch edits reverted to main"
git -C "$T" rev-parse --verify -q refs/remotes/origin/main >/dev/null &&
  ok "origin/main still tracked" || no "origin/main missing"

echo "-- build commit the remote never saw (a local build)"
T="$(deploy feature "0000000000000000000000000000000000000000")"
run_stage "$T"
[[ -f "$T/gui/src/main.js" ]] && ok "tree left alone rather than emptied" || no "tree was destroyed"
[[ "$(cat "$T/bin/cmd")" == "branch version" ]] && ok "files not reverted" || no "files reverted"

echo "-- no .build-commit recorded (an image from before this was added)"
T="$(deploy main "")"
run_stage "$T"
[[ "$(cat "$T/bin/cmd")" == "main version" ]] && ok "falls back to main" || no "fallback broken"

echo
echo "passed=$pass failed=$fail"
((fail == 0))
