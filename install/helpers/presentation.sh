#!/bin/bash

# ANSI Color formatting
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

gnomarchy_header() {
  echo -e "\n${BOLD}${CYAN}==>${NC} ${BOLD}$1${NC}"
}

gnomarchy_step() {
  echo -e "  ${GREEN}✓${NC} $1"
}

gnomarchy_warn() {
  echo -e "  ${YELLOW}⚠${NC} $1"
}

gnomarchy_error() {
  echo -e "  ${RED}✖${NC} $1" >&2
}

gnomarchy_substep() {
  echo -e "    ${DIM}-${NC} $1"
}
