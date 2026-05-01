#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/configs.sh"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: missing required command '$1'" >&2
    exit 1
  fi
}

require_cmd python3
require_cmd ab
require_cmd curl
require_cmd stress-ng
require_cmd sysctl

if ! sudo -n true >/dev/null 2>&1; then
  echo "WARNING: sudo requires a password prompt on this VM."
  echo "Scripts will still work, but may pause for sudo password entry."
fi

echo "Preflight checks passed."
echo "Target URL: $TARGET_URL"
echo "AB concurrency: $AB_CONCURRENCY"
echo "Baseline swappiness: $BASELINE_SWAPPINESS"
