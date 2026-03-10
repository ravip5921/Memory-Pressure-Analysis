#!/bin/bash
set -e

BASE_AB=$1   # e.g., results/baseline/ab.txt
RUNS_DIR=$2  # e.g., results/swap_*/*

OUTFILE="$RUNS_DIR/summary_slowdown.csv"
echo "Swappiness,Stress,Req/sec,Slowdown" > "$OUTFILE"

BASE_RPS=$(grep "Requests per second" "$BASE_AB" | awk '{print $4}')

for AB_FILE in $(find "$RUNS_DIR" -name "ab.txt"); do
    DIR=$(dirname "$AB_FILE")
    # Extract swappiness and stress from folder name
    NAME=$(basename "$DIR")
    SWAP=$(echo "$NAME" | cut -d'_' -f2)
    STRESS=$(echo "$NAME" | cut -d'_' -f3)

    RPS=$(grep "Requests per second" "$AB_FILE" | awk '{print $4}')
    SLOWDOWN=$(echo "scale=4; $BASE_RPS / $RPS" | bc -l)

    echo "$SWAP,$STRESS,$RPS,$SLOWDOWN" >> "$OUTFILE"
done

echo "Slowdown summary saved to $OUTFILE"