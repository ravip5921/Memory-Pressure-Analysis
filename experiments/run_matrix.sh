#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(id -u)" -eq 0 ]; then
  echo "Do NOT run this script with sudo/root."
  echo "Run it as your regular user (it will use 'sudo' internally where needed)."
  exit 1
fi

source "$SCRIPT_DIR/configs.sh"

if ! docker version >/dev/null 2>&1; then
  echo "Docker CLI cannot contact a Docker daemon."
  exit 1
fi

RUN_BASELINE=0
LIST_MISSING=0

for arg in "$@"; do
  case "$arg" in
    --with-baseline)
      RUN_BASELINE=1
      ;;
    --list-missing)
      LIST_MISSING=1
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: $0 [--with-baseline] [--list-missing]" >&2
      exit 1
      ;;
  esac
done

is_complete_run() {
  local outdir="$1"
  local required=(
    ab.txt
    vmstat_before.txt
    vmstat_after.txt
    meminfo_before.txt
    meminfo_after.txt
    oom.txt
    manifest.txt
  )

  [[ -d "$outdir" ]] || return 1
  for f in "${required[@]}"; do
    [[ -f "$outdir/$f" ]] || return 1
  done
  return 0
}

if [[ "$RUN_BASELINE" == "1" ]]; then
  "$SCRIPT_DIR/run_base.sh" "$BASELINE_SWAPPINESS"
fi

missing_count=0
skipped_count=0
run_count=0

for ((rep=1; rep<=REPEAT_COUNT; rep++)); do
  for SWAP in "${SWAPPINESS_LEVELS[@]}"; do
    for LEVEL in "${STRESS_ORDER[@]}"; do
      OUTDIR="$SCRIPT_DIR/$RESULTS_DIR_NAME/swap_${SWAP}_${LEVEL}_r${rep}"

      if is_complete_run "$OUTDIR"; then
        echo "[SKIP] complete: $(basename "$OUTDIR")"
        skipped_count=$((skipped_count + 1))
        continue
      fi

      if [[ "$LIST_MISSING" == "1" ]]; then
        echo "MISSING swap=$SWAP level=$LEVEL repeat=$rep"
        missing_count=$((missing_count + 1))
        continue
      fi

      "$SCRIPT_DIR/run_one.sh" "$SWAP" "$LEVEL" "$rep"
      run_count=$((run_count + 1))
      sleep 5
    done
  done
done

if [[ "$LIST_MISSING" == "1" ]]; then
  echo "Missing runs: $missing_count"
else
  echo "Executed runs: $run_count"
  echo "Skipped complete runs: $skipped_count"
fi

echo "All experiments complete."