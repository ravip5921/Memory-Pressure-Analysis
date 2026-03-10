#!/bin/bash
set -e

source ./configs.sh

for SWAP in "${SWAPPINESS_LEVELS[@]}"
do
  for LEVEL in "${!STRESS_LEVELS[@]}"
  do
    ./run_one.sh $SWAP $LEVEL
    sleep 10
  done
done

echo "All experiments complete."