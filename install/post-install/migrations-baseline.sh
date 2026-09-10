#!/bin/bash

gnomarchy_header "Baselining Migration Ledger"

# A fresh install already produces the end state that every existing migration
# describes, so record them as applied rather than replaying them.
if command -v gnomarchy-migrate >/dev/null 2>&1; then
  gnomarchy-migrate --baseline || true
elif [[ -x "$GNOMARCHY_PATH/bin/gnomarchy-migrate" ]]; then
  "$GNOMARCHY_PATH/bin/gnomarchy-migrate" --baseline || true
fi

gnomarchy_step "Migration ledger baselined"
