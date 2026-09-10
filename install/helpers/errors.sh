#!/bin/bash

handle_error() {
  local exit_code=$?
  local line_number=$1
  echo -e "\n\033[1;31m[ERROR]\033[0m An error occurred on line $line_number (exit code: $exit_code)." >&2
  if [[ -n "${GNOMARCHY_STAGE:-}" ]]; then
    echo -e "\033[1;31m[ERROR]\033[0m Failed during stage: $GNOMARCHY_STAGE" >&2
  fi
  echo -e "Review detailed log output in: $GNOMARCHY_INSTALL_LOG_FILE" >&2
  exit "$exit_code"
}

trap 'handle_error $LINENO' ERR
