#!/bin/bash

gnomarchy_header "Initializing Gnomarchy Repository"

# The ISO deploys Gnomarchy with rsync --exclude=.git, so the installed copy is
# a plain directory. Without a repository `gnomarchy update` can never pull and
# no migration can ever reach the machine.
#
# This runs inside the chroot as the target user, which matters: the earlier
# attempt ran as root against a directory already chowned to uid 1000, and git
# refused it as dubious ownership. That failure was hidden behind 2>/dev/null,
# so the repository silently never appeared.
GNOMARCHY_REPO_URL="${GNOMARCHY_REPO_URL:-https://github.com/hteariH/Gnomarchy.git}"

if [[ -d "$GNOMARCHY_PATH/.git" ]]; then
  gnomarchy_step "Already a git repository"
  return 0 2>/dev/null || exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  gnomarchy_warn "git is unavailable; updates will not be possible"
  return 0 2>/dev/null || exit 0
fi

# Which commit the deployed tree actually is, recorded by iso/builder/build-iso.sh.
#
# This must not be assumed to be main. The index is aligned to whatever is
# fetched here and then `git clean` and `git checkout -- .` enforce it, so
# fetching main against a tree built from another branch deletes every file
# main lacks and reverts every file the branch changed -- including the
# installer scripts that are running at that moment. That is what hung the
# smoke test for 100 minutes: all.sh was rewritten underneath bash, and the
# next stage it tried to source no longer existed.
BUILD_COMMIT_FILE="$GNOMARCHY_INSTALL/.build-commit"
GNOMARCHY_REPO_REF="main"
if [[ -r "$BUILD_COMMIT_FILE" ]]; then
  read -r recorded_commit < "$BUILD_COMMIT_FILE" || recorded_commit=""
  [[ -n "$recorded_commit" ]] && GNOMARCHY_REPO_REF="$recorded_commit"
fi

# Errors are deliberately visible: this step failing silently is exactly how
# machines ended up unable to update.
#
# main is always fetched, because `gnomarchy update` needs refs/remotes/origin/main
# to track. The build commit is fetched as well when the image came from
# somewhere else, and it -- not main -- is what the index is aligned to.
if git -C "$GNOMARCHY_PATH" init -q &&
  git -C "$GNOMARCHY_PATH" remote add origin "$GNOMARCHY_REPO_URL" &&
  git -C "$GNOMARCHY_PATH" fetch -q --depth=1 origin main; then

  ALIGN_TO="FETCH_HEAD"
  if [[ "$GNOMARCHY_REPO_REF" != "main" ]]; then
    if git -C "$GNOMARCHY_PATH" fetch -q --depth=1 origin "$GNOMARCHY_REPO_REF"; then
      ALIGN_TO="$GNOMARCHY_REPO_REF"
      gnomarchy_substep "Image was built from ${GNOMARCHY_REPO_REF:0:7}, not main"
    else
      # Aligning to main would delete or revert everything this image actually
      # contains, so leave the tree alone and say so rather than corrupting it.
      gnomarchy_warn "Image was built from ${GNOMARCHY_REPO_REF:0:7}, which is not on the remote."
      gnomarchy_warn "Leaving the deployed files untouched; 'gnomarchy update' will reconcile."
      ALIGN_TO=""
    fi
  fi

  # The working tree is already the right content; align the index with the
  # commit it was built from rather than overwriting files.
  [[ -n "$ALIGN_TO" ]] && git -C "$GNOMARCHY_PATH" reset -q --mixed "$ALIGN_TO" || true
  git -C "$GNOMARCHY_PATH" branch -q -M main 2>/dev/null || true
  git -C "$GNOMARCHY_PATH" branch -q --set-upstream-to=origin/main main 2>/dev/null || true

  # Deployed, not authored: permission-only differences must never dirty it.
  git -C "$GNOMARCHY_PATH" config core.fileMode false

  # Drop anything the image build left behind that is not part of the repo.
  #
  # Only ever with an index that matches the deployed tree. Without the reset
  # above the index is empty, and `git clean -fd` against an empty index
  # deletes the entire installation.
  if [[ -n "$ALIGN_TO" ]]; then
    git -C "$GNOMARCHY_PATH" clean -qfd -e themes -e default 2>/dev/null || true
    git -C "$GNOMARCHY_PATH" checkout -q -- . 2>/dev/null || true
  fi

  gnomarchy_step "Repository initialized ($(git -C "$GNOMARCHY_PATH" rev-parse --short HEAD 2>/dev/null || echo unknown))"
else
  gnomarchy_warn "Could not initialize the repository"
  gnomarchy_warn "'gnomarchy update' will retry on first run"
  rm -rf "$GNOMARCHY_PATH/.git"
fi
