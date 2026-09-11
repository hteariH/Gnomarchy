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

# Errors are deliberately visible: this step failing silently is exactly how
# machines ended up unable to update.
if git -C "$GNOMARCHY_PATH" init -q &&
  git -C "$GNOMARCHY_PATH" remote add origin "$GNOMARCHY_REPO_URL" &&
  git -C "$GNOMARCHY_PATH" fetch -q --depth=1 origin main; then

  # The working tree is already the right content; align the index with the
  # fetched commit rather than overwriting files.
  git -C "$GNOMARCHY_PATH" reset -q --mixed FETCH_HEAD || true
  git -C "$GNOMARCHY_PATH" branch -q -M main 2>/dev/null || true
  git -C "$GNOMARCHY_PATH" branch -q --set-upstream-to=origin/main main 2>/dev/null || true

  # Deployed, not authored: permission-only differences must never dirty it.
  git -C "$GNOMARCHY_PATH" config core.fileMode false

  # Drop anything the image build left behind that is not part of the repo.
  git -C "$GNOMARCHY_PATH" clean -qfd -e themes -e default 2>/dev/null || true
  git -C "$GNOMARCHY_PATH" checkout -q -- . 2>/dev/null || true

  gnomarchy_step "Repository initialized ($(git -C "$GNOMARCHY_PATH" rev-parse --short HEAD 2>/dev/null || echo unknown))"
else
  gnomarchy_warn "Could not initialize the repository"
  gnomarchy_warn "'gnomarchy update' will retry on first run"
  rm -rf "$GNOMARCHY_PATH/.git"
fi
