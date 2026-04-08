#!/bin/bash
set -euo pipefail

# Resolve script and repo directories (so the script can be invoked from any CWD)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load experiment configuration (this script lives in the experiments/ directory)
source "$SCRIPT_DIR/configs.sh"

# If this script is executed as root (for example via `sudo bash run_one.sh`),
# Docker CLI may lose the per-user Docker Desktop context and try to use
# /var/run/docker.sock. Run the script as your normal user (the script uses
# sudo internally where necessary). If the script is run as root, warn and exit.
if [ "$(id -u)" -eq 0 ]; then
  echo "Do NOT run this script as root/sudo."
  echo "Invoke it as your regular user (the script will call 'sudo' for privileged operations)."
  exit 1
fi

# Quick check that Docker is reachable
if ! docker version >/dev/null 2>&1; then
  echo "Docker CLI cannot contact a Docker daemon. Ensure Docker Desktop is running and the CLI context is correct."
  echo "Try: docker context ls && docker context use desktop-linux"
  exit 1
fi

SWAP=$1
LEVEL=$2
STRESS_BYTES=${STRESS_LEVELS[$LEVEL]}

OUTDIR="results/swap_${SWAP}_${LEVEL}"
mkdir -p "$OUTDIR"

C1="service"
C2="stressor"
IMAGE="memory-pressure-app"

# Allow overriding the image via environment for flexibility
IMAGE="${IMAGE:-memory-pressure-app}"

# Cleanup function to remove containers on exit
cleanup() {
  docker rm -f "$C1" "$C2" 2>/dev/null || true
}
trap cleanup EXIT

# Scale concurrency based on stress level
if [[ "$LEVEL" == "extreme" ]]; then
    AB_CONCURRENCY=5
elif [[ "$LEVEL" == "high" ]]; then
    AB_CONCURRENCY=5
else
    AB_CONCURRENCY=5
fi

echo "=========================================="
echo "Running swappiness=$SWAP, stress=$LEVEL"
echo "=========================================="

# Set swappiness
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

docker rm -f $C1 $C2 2>/dev/null || true

# Start service container
# Ensure the Docker image exists; if not, try to build it from the repo root so COPY can find workloads/
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Docker image '$IMAGE' not found locally; attempting to build from repo root..."
  if ! docker build -t "$IMAGE" -f "$REPO_ROOT/docker/Dockerfile" "$REPO_ROOT"; then
    echo "ERROR: failed to build image '$IMAGE'. Ensure you're running this script from the repository root so the Docker build context (.) contains the 'workloads/' directory." >&2
    exit 1
  fi
fi

docker run -d \
  --name $C1 \
  --memory="$SERVICE_MEM" \
  --memory-swap="$SERVICE_SWAP" \
  -p 8080:8080 \
  $IMAGE

# Wait until service is ready
echo "[*] Waiting for service to be ready..."
wait_for_service() {
  local timeout=30
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    # Try host curl (service is published to host via -p 8080:8080)
    if curl -sS --fail -o /dev/null http://127.0.0.1:8080/ >/dev/null 2>&1; then
      echo "Service is responding on host:8080"
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  echo "WARNING: service did not become ready after ${timeout}s; continuing anyway."
  return 1
}

wait_for_service || true
# Start stress container
docker run -d \
  --name $C2 \
  --memory="$STRESS_BYTES" \
  $IMAGE \
  stress-ng --vm 1 --vm-bytes $STRESS_BYTES --timeout 600s

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

docker rm -f $C1 $C2

echo "Completed swap=$SWAP level=$LEVEL"

################################################################################################################3
# #!/bin/bash
# set -e
# source ./configs.sh

# SWAP=$1
# LEVEL=$2
# STRESS_BYTES=${STRESS_LEVELS[$LEVEL]}
# # STRESS_MB=$((STRESS_BYTES / 1024 / 1024))

# OUTDIR="results/swap_${SWAP}_${LEVEL}"
# mkdir -p "$OUTDIR"

# C1="service"
# C2="stressor"
# IMAGE="memory-pressure-app"

# echo "=========================================="
# echo "Running swappiness=$SWAP, stress=$LEVEL"
# echo "=========================================="

# # Kernel tuning
# sudo sysctl -w vm.swappiness=$SWAP
# sudo sysctl -w net.core.somaxconn=65535
# sudo sysctl -w net.ipv4.tcp_max_syn_backlog=65535
# sudo sysctl -w net.ipv4.tcp_syncookies=1
# ulimit -n 100000

# # # Check available memory
# # AVAILABLE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
# # if [ $AVAILABLE -lt $((SERVICE_MEM_MB + STRESS_MB)) ]; then
# #     echo "WARNING: Not enough free memory for this configuration ($AVAILABLE kB available)"
# #     # Reduce stress bytes
# #     STRESS_BYTES=$((AVAILABLE*1024 - SERVICE_MEM))
# #     echo "Reducing stress container memory to $STRESS_BYTES bytes"
# # fi

# # Record BEFORE snapshot
# cat /proc/vmstat > "$OUTDIR/vmstat_before.txt"
# cat /proc/meminfo > "$OUTDIR/meminfo_before.txt"

# docker rm -f $C1 $C2 2>/dev/null || true

# # Start service container
# docker run -d \
#   --name $C1 \
#   --memory="$SERVICE_MEM" \
#   --memory-swap="$SERVICE_SWAP" \
#   --ulimit nofile=100000:100000 \
#   -p 8080:8080 \
#   $IMAGE

# sleep 5

# # Start stress container
# docker run -d \
#   --name $C2 \
#   --memory="$STRESS_BYTES" \
#   --memory-swap="$STRESS_BYTES" \
#   $IMAGE \
#   stress-ng --vm 1 --vm-bytes $STRESS_BYTES --timeout 40s --vm-keep

# sleep 5

# # Run ApacheBench (reduced concurrency to prevent resets)
# docker run --rm --network host jordi/ab \
#   -t $RUN_TIME -c $CONCURRENCY -s $TIMEOUT \
#   http://127.0.0.1:8080/ \
#   > "$OUTDIR/ab.txt" 2> "$OUTDIR/ab_err.txt"

# # Record AFTER snapshot
# cat /proc/vmstat > "$OUTDIR/vmstat_after.txt"
# cat /proc/meminfo > "$OUTDIR/meminfo_after.txt"
# dmesg | grep -i oom > "$OUTDIR/oom.txt" || true

# docker rm -f $C1 $C2

# echo "Completed swap=$SWAP level=$LEVEL"


