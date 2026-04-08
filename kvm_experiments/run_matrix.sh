#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/configs.sh"

RUN_BASELINE=0
if [[ "${1:-}" == "--with-baseline" ]]; then
  RUN_BASELINE=1
fi

if [[ "$RUN_BASELINE" == "1" ]]; then
  "$SCRIPT_DIR/run_base.sh" "$BASELINE_SWAPPINESS"
fi

for ((rep=1; rep<=REPEAT_COUNT; rep++)); do
  for SWAP in "${SWAPPINESS_LEVELS[@]}"; do
    for LEVEL in "${STRESS_ORDER[@]}"; do
      "$SCRIPT_DIR/run_one.sh" "$SWAP" "$LEVEL" "$rep"
      sleep 5
    done
  done
done

echo "All KVM experiments complete."
