#!/bin/bash
set -euo pipefail

# Resolve script and repo directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load config from script directory
source "$SCRIPT_DIR/configs.sh"

SWAP=$1
LEVEL=$2

OUTDIR="$SCRIPT_DIR/results/baseline_swap_${SWAP}_${LEVEL}"
mkdir -p "$OUTDIR"

C1="service"
IMAGE="memory-pressure-app"

# Scale concurrency based on stress level
if [[ "$LEVEL" == "extreme" ]]; then
    AB_CONCURRENCY=5
elif [[ "$LEVEL" == "high" ]]; then
    AB_CONCURRENCY=10
else
    AB_CONCURRENCY=15
fi

echo "=========================================="
echo "Running BASELINE: swappiness=$SWAP, stress=$LEVEL (service alone)"
echo "=========================================="

try_sysctl() {
  # Try to apply a sysctl safely. If sudo fails (PAM/password issues), warn and continue.
  if sudo sysctl -w "$1" >/dev/null 2>&1; then
    echo "Applied sysctl $1"
  else
    echo "WARNING: failed to apply sysctl '$1'. This often means sudo requires a password or PAM cannot authenticate your account."
    echo "Continuing without this tuning. To enable tuning, fix your sudo/PAM configuration or run the sysctl commands as root." \
         "(e.g. sudo sysctl -w $1)"
  fi
}
# Set swappiness
try_sysctl "vm.swappiness=$SWAP"

# Tune host network for high concurrency
echo "[*] Tuning host network..."
try_sysctl "net.core.somaxconn=65535"
try_sysctl "net.ipv4.tcp_max_syn_backlog=65535"
try_sysctl "net.ipv4.tcp_syncookies=1"
try_sysctl "net.ipv4.ip_local_port_range=\"1024 65535\""
try_sysctl "net.ipv4.tcp_tw_reuse=1"
try_sysctl "net.ipv4.tcp_fin_timeout=10"
try_sysctl "net.ipv4.tcp_max_orphans=262144"

# Record BEFORE snapshot
cat /proc/vmstat > "$OUTDIR/vmstat_before.txt"
cat /proc/meminfo > "$OUTDIR/meminfo_before.txt"

docker rm -f "$C1" 2>/dev/null || true

# Ensure image exists (build from repo root if needed)
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Docker image '$IMAGE' not found locally; attempting to build..."
  if ! docker build -t "$IMAGE" -f "$REPO_ROOT/docker/Dockerfile" "$REPO_ROOT"; then
    echo "ERROR: failed to build image '$IMAGE'" >&2
    exit 1
  fi
fi

# Start service container alone (host network used so clients on the host can reach it)
docker run -d \
  --name "$C1" \
  --memory="$SERVICE_MEM" \
  --memory-swap="$SERVICE_SWAP" \
  --network host \
  "$IMAGE"

# Wait until service responds on host:8080
echo "[*] Waiting for service to be ready..."
timeout=30; elapsed=0
while [ $elapsed -lt $timeout ]; do
  if curl -sS --fail -o /dev/null http://127.0.0.1:8080/ >/dev/null 2>&1; then
    echo "Service is responding on host:8080"
    break
  fi
  sleep 1
  elapsed=$((elapsed+1))
done
if [ $elapsed -ge $timeout ]; then
  echo "WARNING: service did not respond after ${timeout}s; continuing anyway"
fi

# Run ApacheBench with keep-alive
docker run --rm --network host jordi/ab \
  -k \
  -n $AB_REQUESTS \
  -c $AB_CONCURRENCY \
  -t $RUN_TIME \
  -s $TIMEOUT \
  http://127.0.0.1:8080/ \
  > "$OUTDIR/ab.txt"

# Record AFTER snapshot
cat /proc/vmstat > "$OUTDIR/vmstat_after.txt"
cat /proc/meminfo > "$OUTDIR/meminfo_after.txt"
dmesg | grep -i oom > "$OUTDIR/oom.txt" || true

docker rm -f "$C1"

echo "Baseline run completed for swappiness=$SWAP, stress=$LEVEL"