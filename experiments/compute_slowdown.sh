#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS_DIR="${1:-$SCRIPT_DIR/results}"
BASE_AB="$RUNS_DIR/baseline/ab.txt"
OUTFILE="$SCRIPT_DIR/summary_slowdown_raw.csv"

if [[ ! -f "$BASE_AB" ]]; then
    echo "ERROR: missing baseline AB file: $BASE_AB" >&2
    exit 1
fi

BASE_RPS=$(grep "Requests per second" "$BASE_AB" | awk '{print $4}')
if [[ -z "$BASE_RPS" ]]; then
    echo "ERROR: failed to parse baseline Requests per second" >&2
    exit 1
fi

echo "Swappiness,Stress,Repeat,ReqPerSec,Slowdown" > "$OUTFILE"

while IFS= read -r AB_FILE; do
    DIR=$(dirname "$AB_FILE")
    NAME=$(basename "$DIR")

    if [[ "$NAME" == "baseline" ]]; then
        continue
    fi

    if [[ ! "$NAME" =~ ^swap_([0-9]+)_(moderate|high|extreme)_r([0-9]+)$ ]]; then
        continue
    fi

    SWAP="${BASH_REMATCH[1]}"
    STRESS="${BASH_REMATCH[2]}"
    REPEAT="${BASH_REMATCH[3]}"

    RPS=$(grep "Requests per second" "$AB_FILE" | awk '{print $4}')
    if [[ -z "$RPS" ]]; then
        continue
    fi

    SLOWDOWN=$(echo "scale=6; $BASE_RPS / $RPS" | bc -l)
    echo "$SWAP,$STRESS,$REPEAT,$RPS,$SLOWDOWN" >> "$OUTFILE"
done < <(find "$RUNS_DIR" -type f -name "ab.txt" | sort)

echo "Slowdown summary saved to $OUTFILE"