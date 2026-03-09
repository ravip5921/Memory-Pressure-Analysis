#!/bin/bash
set -e

OUTDIR="results/docker/interference"
IMAGE_NAME="memory-pressure-app"

C1="service"
C2="stressor"

mkdir -p "$OUTDIR"

echo "[1/7] Cleaning old containers..."
docker rm -f $C1 $C2 2>/dev/null || true

echo "[2/7] Building image..."
docker build -t $IMAGE_NAME -f docker/Dockerfile .

############################################
# BASELINE (C1 ALONE)
############################################

echo "[3/7] Starting latency container alone..."
docker run -d \
  --name $C1 \
  --memory="512m" \
  --memory-swap="1g" \
  -p 8080:8080 \
  $IMAGE_NAME

sleep 5

echo "Running baseline benchmark..."
docker run --rm --network host jordi/ab \
  -n 2000 -c 20 -s 60 http://127.0.0.1:8080/ \
  > "$OUTDIR/baseline.txt"

docker rm -f $C1

############################################
# CONTENDED (C1 + C2)
############################################

echo "[4/7] Starting latency container (C1)..."
docker run -d \
  --name $C1 \
  --memory="512m" \
  --memory-swap="1g" \
  -p 8080:8080 \
  $IMAGE_NAME

sleep 5

echo "[5/7] Starting stress container (C2)..."
docker run -d \
  --name $C2 \
  --memory="700m" \
  --memory-swap="1g" \
  $IMAGE_NAME \
  stress-ng --vm 1 --vm-bytes 600m --timeout 40s

sleep 5

echo "Running benchmark under interference..."
docker run --rm --network host jordi/ab \
  -n 2000 -c 20 -s 60 http://127.0.0.1:8080/ \
  > "$OUTDIR/contended.txt"

echo "[6/7] Collecting kernel stats..."
cat /proc/vmstat > "$OUTDIR/host_vmstat.txt"
cat /proc/meminfo > "$OUTDIR/host_meminfo.txt"
dmesg | grep -i oom > "$OUTDIR/oom_log.txt" || true

docker rm -f $C1 $C2

echo "[7/7] Done."