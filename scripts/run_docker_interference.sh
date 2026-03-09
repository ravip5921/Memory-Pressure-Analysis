#!/bin/bash
set -e

OUTDIR="results/docker/interference"
IMAGE_NAME="memory-pressure-app"

C1="service"
C2="stressor"

mkdir -p "$OUTDIR"

echo "[1/9] Cleaning old containers..."
docker rm -f $C1 $C2 2>/dev/null || true

echo "[2/9] Building image..."
docker build -t $IMAGE_NAME -f docker/Dockerfile .

############################################################
# BASELINE (C1 ALONE)
############################################################

echo "[3/9] BASELINE: Capturing host state BEFORE..."
cat /proc/vmstat > "$OUTDIR/baseline_host_vmstat_before.txt"
cat /proc/meminfo > "$OUTDIR/baseline_host_meminfo_before.txt"

echo "Starting latency container alone..."
docker run -d \
  --name $C1 \
  --memory="512m" \
  --memory-swap="1g" \
  -p 8080:8080 \
  $IMAGE_NAME

sleep 5

echo "Collecting C1 container state BEFORE benchmark..."
docker stats --no-stream $C1 > "$OUTDIR/baseline_c1_dockerstats_before.txt"
docker exec $C1 cat /proc/meminfo > "$OUTDIR/baseline_c1_meminfo_before.txt"
docker exec $C1 cat /proc/vmstat > "$OUTDIR/baseline_c1_vmstat_before.txt"

echo "Running baseline benchmark..."
docker run --rm --network host jordi/ab \
  -n 2000 -c 20 -s 60 http://127.0.0.1:8080/ \
  > "$OUTDIR/baseline.txt"

echo "Collecting C1 container state AFTER benchmark..."
docker stats --no-stream $C1 > "$OUTDIR/baseline_c1_dockerstats_after.txt"
docker exec $C1 cat /proc/meminfo > "$OUTDIR/baseline_c1_meminfo_after.txt"
docker exec $C1 cat /proc/vmstat > "$OUTDIR/baseline_c1_vmstat_after.txt"

echo "Capturing host state AFTER baseline..."
cat /proc/vmstat > "$OUTDIR/baseline_host_vmstat_after.txt"
cat /proc/meminfo > "$OUTDIR/baseline_host_meminfo_after.txt"
dmesg | grep -i oom > "$OUTDIR/baseline_oom_log.txt" || true

docker rm -f $C1

############################################################
# CONTENDED (C1 + C2)
############################################################

echo "[4/9] CONTENDED: Capturing host state BEFORE..."
cat /proc/vmstat > "$OUTDIR/contended_host_vmstat_before.txt"
cat /proc/meminfo > "$OUTDIR/contended_host_meminfo_before.txt"

echo "Starting latency container (C1)..."
docker run -d \
  --name $C1 \
  --memory="512m" \
  --memory-swap="1g" \
  -p 8080:8080 \
  $IMAGE_NAME

sleep 5

echo "Starting stress container (C2)..."
docker run -d \
  --name $C2 \
  --memory="700m" \
  --memory-swap="1g" \
  $IMAGE_NAME \
  stress-ng --vm 1 --vm-bytes 600m --timeout 40s

sleep 5

echo "Collecting C1 and C2 state BEFORE benchmark..."
docker stats --no-stream $C1 $C2 > "$OUTDIR/contended_dockerstats_before.txt"

docker exec $C1 cat /proc/meminfo > "$OUTDIR/contended_c1_meminfo_before.txt"
docker exec $C1 cat /proc/vmstat > "$OUTDIR/contended_c1_vmstat_before.txt"

docker exec $C2 cat /proc/meminfo > "$OUTDIR/contended_c2_meminfo_before.txt"
docker exec $C2 cat /proc/vmstat > "$OUTDIR/contended_c2_vmstat_before.txt"

echo "Running benchmark under interference..."
docker run --rm --network host jordi/ab \
  -n 2000 -c 20 -s 60 http://127.0.0.1:8080/ \
  > "$OUTDIR/contended.txt"

echo "Collecting C1 and C2 state AFTER benchmark..."
docker stats --no-stream $C1 $C2 > "$OUTDIR/contended_dockerstats_after.txt"

docker exec $C1 cat /proc/meminfo > "$OUTDIR/contended_c1_meminfo_after.txt"
docker exec $C1 cat /proc/vmstat > "$OUTDIR/contended_c1_vmstat_after.txt"

docker exec $C2 cat /proc/meminfo > "$OUTDIR/contended_c2_meminfo_after.txt"
docker exec $C2 cat /proc/vmstat > "$OUTDIR/contended_c2_vmstat_after.txt"

echo "Capturing host state AFTER contended run..."
cat /proc/vmstat > "$OUTDIR/contended_host_vmstat_after.txt"
cat /proc/meminfo > "$OUTDIR/contended_host_meminfo_after.txt"
dmesg | grep -i oom > "$OUTDIR/contended_oom_log.txt" || true

docker rm -f $C1 $C2

echo "[9/9] Experiment complete."