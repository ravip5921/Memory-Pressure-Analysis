#!/bin/bash

# Swappiness levels
SWAPPINESS_LEVELS=(10 60 100)

# Memory pressure levels
declare -A STRESS_LEVELS
STRESS_LEVELS=(
  [moderate]="400m"
  [high]="800m"
  [extreme]="1200m"
)

CONCURRENCY=30
TIMEOUT=600

SERVICE_MEM="2g"
SERVICE_SWAP="2g"

# Reduce concurrency for long stable runs
AB_KEEP_ALIVE=1       # enable ApacheBench keep-alive
# Adjust AB concurrency if needed
AB_CONCURRENCY_DEFAULT=10

# Optionally increase requests to match runtime
AB_REQUESTS=2000      # enough for long run
RUN_TIME=30           # duration of each benchmark in seconds

# TCP tuning parameters for long experiments
TCP_FIN_TIMEOUT=10
TCP_TW_REUSE=1
TCP_MAX_ORPHANS=262144