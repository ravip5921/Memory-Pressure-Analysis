#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/configs.sh"

if [ "$(id -u)" -eq 0 ]; then
  echo "Do NOT run this script as root/sudo."
  echo "Invoke it as your regular user (the script will call 'sudo' for privileged operations)."
  exit 1
fi

if ! docker version >/dev/null 2>&1; then
  echo "Docker CLI cannot contact a Docker daemon."
  exit 1
fi

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <swappiness> <stress_level> [repeat_index]" >&2
  exit 1
fi

SWAP="$1"
LEVEL="$2"
REPEAT_INDEX="${3:-1}"

if [[ -z "${STRESS_LEVELS[$LEVEL]:-}" ]]; then
  echo "ERROR: unknown stress level '$LEVEL'" >&2
  exit 1
fi

STRESS_BYTES="${STRESS_LEVELS[$LEVEL]}"

OUTDIR="$SCRIPT_DIR/$RESULTS_DIR_NAME/swap_${SWAP}_${LEVEL}_r${REPEAT_INDEX}"
mkdir -p "$OUTDIR"

C1="service"
C2="stressor"

cleanup() {
  docker rm -f "$C1" "$C2" 2>/dev/null || true
}
trap cleanup EXIT

echo "=========================================="
echo "Running swappiness=$SWAP, stress=$LEVEL, repeat=$REPEAT_INDEX"
echo "=========================================="

try_sysctl() {
  if sudo sysctl -w "$1" >/dev/null 2>&1; then
    echo "Applied sysctl $1"
  else
    echo "WARNING: failed to apply sysctl '$1'. Continuing without this tuning."
  fi
}

try_sysctl "vm.swappiness=$SWAP"

echo "[*] Tuning host network..."
try_sysctl "net.core.somaxconn=65535"
try_sysctl "net.ipv4.tcp_max_syn_backlog=65535"
try_sysctl "net.ipv4.tcp_syncookies=1"
try_sysctl "net.ipv4.ip_local_port_range=1024 65535"
try_sysctl "net.ipv4.tcp_tw_reuse=$TCP_TW_REUSE"
try_sysctl "net.ipv4.tcp_fin_timeout=$TCP_FIN_TIMEOUT"
try_sysctl "net.ipv4.tcp_max_orphans=$TCP_MAX_ORPHANS"

cat /proc/vmstat > "$OUTDIR/vmstat_before.txt"
cat /proc/meminfo > "$OUTDIR/meminfo_before.txt"

docker rm -f "$C1" "$C2" 2>/dev/null || true

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Docker image '$IMAGE' not found locally; attempting to build from repo root..."
  if ! docker build -t "$IMAGE" -f "$REPO_ROOT/docker/Dockerfile" "$REPO_ROOT"; then
    echo "ERROR: failed to build image '$IMAGE'." >&2
    exit 1
  fi
fi

docker run -d \
  --name "$C1" \
  --memory="$SERVICE_MEM" \
  --memory-swap="$SERVICE_SWAP" \
  --network host \
  "$IMAGE"

echo "[*] Waiting for service to be ready..."
wait_for_service() {
  local timeout=30
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    if docker exec "$C1" curl -sS --fail -o /dev/null http://127.0.0.1:8080/ >/dev/null 2>&1; then
      echo "Service is responding inside container on :8080"
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  echo "WARNING: service did not become ready after ${timeout}s; continuing anyway."
  return 1
}

wait_for_service || true

docker run -d \
  --name "$C2" \
  --memory="$STRESS_BYTES" \
  "$IMAGE" \
  stress-ng --vm 1 --vm-bytes "$STRESS_BYTES" --timeout 600s

AB_ARGS=(
  -n "$AB_REQUESTS"
  -c "$AB_CONCURRENCY"
  -t "$RUN_TIME"
  -s "$TIMEOUT"
)

if [[ "$AB_KEEP_ALIVE" == "1" ]]; then
  AB_ARGS=(-k "${AB_ARGS[@]}")
fi

RUN_TS="$(date -Iseconds)"
{
  echo "run_type=stressed"
  echo "run_timestamp=$RUN_TS"
  echo "repeat_index=$REPEAT_INDEX"
  echo "swappiness=$SWAP"
  echo "stress_level=$LEVEL"
  echo "stress_bytes=$STRESS_BYTES"
  echo "ab_concurrency=$AB_CONCURRENCY"
  echo "ab_requests=$AB_REQUESTS"
  echo "ab_runtime_seconds=$RUN_TIME"
  echo "ab_timeout_seconds=$TIMEOUT"
  echo "image=$IMAGE"
  echo "kernel=$(uname -r)"
  echo "swappiness_effective=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo unknown)"
  echo "service_mem=$SERVICE_MEM"
  echo "service_swap=$SERVICE_SWAP"
} > "$OUTDIR/manifest.txt"

docker run --rm --network host jordi/ab "${AB_ARGS[@]}" \
  http://127.0.0.1:8080/ > "$OUTDIR/ab.txt"

cat /proc/vmstat > "$OUTDIR/vmstat_after.txt"
cat /proc/meminfo > "$OUTDIR/meminfo_after.txt"
sudo dmesg | grep -i oom > "$OUTDIR/oom.txt" || true

docker rm -f "$C1" "$C2" >/dev/null 2>&1 || true

echo "Completed swap=$SWAP level=$LEVEL repeat=$REPEAT_INDEX"


