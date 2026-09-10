#!/bin/bash

gnomarchy_header "Configuring Docker Container Engine"

if command -v docker >/dev/null 2>&1; then
  sudo systemctl enable docker.service >/dev/null 2>&1 || true
  sudo usermod -aG docker "$USER" 2>/dev/null || true
  gnomarchy_step "Docker service enabled and user added to docker group"
fi
