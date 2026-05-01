#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/configs.sh"

if [ "$(id -u)" -eq 0 ]; then
  echo "Do NOT run this script with sudo/root."
  echo "Run it as your regular user (it will use 'sudo' internally where needed)."
  exit 1
fi

# Quick check that the Docker CLI can contact a server
if ! docker version >/dev/null 2>&1; then
  echo "Docker CLI cannot contact a Docker daemon."
  exit 1
fi

"$SCRIPT_DIR/run_base.sh" "$BASELINE_SWAPPINESS"

echo "Single global baseline completed."