#!/bin/bash

# Experiment matrix
SWAPPINESS_LEVELS=(10 60 100)
STRESS_ORDER=(moderate high extreme)

declare -A STRESS_LEVELS=(
  [moderate]="400m"
  [high]="800m"
  [extreme]="1200m"
)

# Baseline policy
BASELINE_MODE="single_global"
BASELINE_SWAPPINESS=60

# Workload settings
AB_REQUESTS=2000
AB_CONCURRENCY=30
RUN_TIME=30
TIMEOUT=600
AB_KEEP_ALIVE=1
TARGET_URL="http://127.0.0.1:8080/"

# Reproducibility settings
REPEAT_COUNT=3
RESULTS_DIR_NAME="results"

# Host tuning knobs
TCP_FIN_TIMEOUT=10
TCP_TW_REUSE=1
TCP_MAX_ORPHANS=262144
