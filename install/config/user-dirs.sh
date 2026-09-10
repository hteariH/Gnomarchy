#!/bin/bash

# Ensure standard user directories exist
xdg-user-dirs-update >/dev/null 2>&1 || true
mkdir -p "$HOME/Developer" "$HOME/Screenshots"
