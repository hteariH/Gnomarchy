#!/bin/bash

gnomarchy_header "Deploying Gnomarchy AI Agent Skills"

SKILL_SOURCE="$GNOMARCHY_PATH/default/gnomarchy-skill"

if [ -d "$SKILL_SOURCE" ]; then
  # Deploy to standard AI coding agent skill directories
  AGENT_DIRS=(
    "$HOME/.agents/skills"
    "$HOME/.claude/skills"
    "$HOME/.codex/skills"
    "$HOME/.pi/agent/skills"
    "$HOME/.gemini/antigravity/skills"
    "$HOME/.config/opencode/skills"
  )

  for dir in "${AGENT_DIRS[@]}"; do
    mkdir -p "$dir"
    ln -sfn "$SKILL_SOURCE" "$dir/gnomarchy" 2>/dev/null || true
  done

  gnomarchy_step "Gnomarchy skill deployed to Claude Code, Codex, Pi, and open agent registries"
fi
