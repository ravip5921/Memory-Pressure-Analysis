#!/bin/bash
set -e

source ./configs.sh

SWAP=$1
LEVEL=$2

OUTDIR="results/baseline_swap_${SWAP}_${LEVEL}"
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

# Set swappiness
sudo sysctl vm.swappiness=$SWAP

# Tune host network for high concurrency
echo "[*] Tuning host network..."
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=65535
sudo sysctl -w net.ipv4.tcp_syncookies=1
sudo sysctl -w net.ipv4.ip_local_port_range="1024 65535"
sudo sysctl -w net.ipv4.tcp_tw_reuse=1
sudo sysctl -w net.ipv4.tcp_fin_timeout=10
sudo sysctl -w net.ipv4.tcp_max_orphans=262144

# Record BEFORE snapshot
cat /proc/vmstat > "$OUTDIR/vmstat_before.txt"
cat /proc/meminfo > "$OUTDIR/meminfo_before.txt"

docker rm -f $C1 2>/dev/null || true

# Start service container alone
docker run -d \
  --name $C1 \
  --memory="$SERVICE_MEM" \
  --memory-swap="$SERVICE_SWAP" \
  --network host \
  $IMAGE

# Wait until service is ready
echo "[*] Waiting for service to be ready..."
sleep 5

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

docker rm -f $C1

echo "Baseline run completed for swappiness=$SWAP, stress=$LEVEL"