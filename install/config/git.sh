#!/bin/bash

# Configure sensible git defaults if git isn't configured yet
if [ -z "$(git config --global init.defaultBranch)" ]; then
  git config --global init.defaultBranch main
fi
git config --global pull.rebase true
git config --global core.editor nvim
