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

# Reproducibility settings
REPEAT_COUNT=3
RESULTS_DIR_NAME="results"
IMAGE="memory-pressure-app"

# Container memory limits
SERVICE_MEM="2g"
SERVICE_SWAP="2g"

# Host tuning knobs
TCP_FIN_TIMEOUT=10
TCP_TW_REUSE=1
TCP_MAX_ORPHANS=262144