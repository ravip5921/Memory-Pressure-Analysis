#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/configs.sh"

SWAP="${1:-$BASELINE_SWAPPINESS}"
OUTDIR="${2:-$SCRIPT_DIR/$RESULTS_DIR_NAME/baseline}"

mkdir -p "$OUTDIR"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: missing required command '$1'" >&2
    exit 1
  fi
}

require_cmd python3
require_cmd ab
require_cmd curl
require_cmd sysctl

if [[ ! -f "$REPO_ROOT/workloads/latency_server.py" ]]; then
  echo "ERROR: workload server missing at $REPO_ROOT/workloads/latency_server.py" >&2
  exit 1
fi

if [[ ! -w "$OUTDIR" ]]; then
  echo "ERROR: output directory is not writable: $OUTDIR" >&2
  exit 1
fi

try_sysctl() {
  if sudo sysctl -w "$1" >/dev/null 2>&1; then
    echo "Applied sysctl $1"
  else
    echo "WARNING: failed to apply sysctl '$1'. Continuing without this tuning."
  fi
}

echo "=========================================="
echo "Running KVM BASELINE: swappiness=$SWAP"
echo "=========================================="

try_sysctl "vm.swappiness=$SWAP"

echo "[*] Tuning guest network..."
try_sysctl "net.core.somaxconn=65535"
try_sysctl "net.ipv4.tcp_max_syn_backlog=65535"
try_sysctl "net.ipv4.tcp_syncookies=1"
try_sysctl "net.ipv4.ip_local_port_range=1024 65535"
try_sysctl "net.ipv4.tcp_tw_reuse=$TCP_TW_REUSE"
try_sysctl "net.ipv4.tcp_fin_timeout=$TCP_FIN_TIMEOUT"
try_sysctl "net.ipv4.tcp_max_orphans=$TCP_MAX_ORPHANS"

cat /proc/vmstat > "$OUTDIR/vmstat_before.txt"
cat /proc/meminfo > "$OUTDIR/meminfo_before.txt"

SERVER_LOG="$OUTDIR/server.log"
python3 "$REPO_ROOT/workloads/latency_server.py" > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!

cleanup() {
  kill "$SERVER_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "[*] Waiting for service to be ready..."
timeout=30
elapsed=0
while [ $elapsed -lt $timeout ]; do
  if curl -sS --fail -o /dev/null "$TARGET_URL" >/dev/null 2>&1; then
    echo "Service is responding on $TARGET_URL"
    break
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done
if [ $elapsed -ge $timeout ]; then
  echo "WARNING: service did not respond after ${timeout}s; continuing anyway"
fi

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
  echo "run_type=baseline"
  echo "run_timestamp=$RUN_TS"
  echo "baseline_mode=$BASELINE_MODE"
  echo "baseline_swappiness=$SWAP"
  echo "ab_concurrency=$AB_CONCURRENCY"
  echo "ab_requests=$AB_REQUESTS"
  echo "ab_runtime_seconds=$RUN_TIME"
  echo "ab_timeout_seconds=$TIMEOUT"
  echo "target_url=$TARGET_URL"
  echo "kernel=$(uname -r)"
  echo "swappiness_effective=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo unknown)"
} > "$OUTDIR/manifest.txt"

ab "${AB_ARGS[@]}" "$TARGET_URL" > "$OUTDIR/ab.txt"

cat /proc/vmstat > "$OUTDIR/vmstat_after.txt"
cat /proc/meminfo > "$OUTDIR/meminfo_after.txt"
sudo dmesg | grep -i oom > "$OUTDIR/oom.txt" || true

echo "Baseline run completed for swappiness=$SWAP"
