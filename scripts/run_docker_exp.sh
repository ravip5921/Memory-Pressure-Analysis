#!/bin/bash

set -e

OUTDIR="results/docker/exp1"
IMAGE_NAME="memory-pressure-app"
CONTAINER_NAME="service"

mkdir -p "$OUTDIR"

echo "[1/6] Cleaning up old container..."
docker rm -f $CONTAINER_NAME 2>/dev/null || true
docker ps -q --filter "publish=8080" | xargs -r docker rm -f

echo "[2/6] Building Docker image..."
docker build -t $IMAGE_NAME -f docker/Dockerfile .

echo "[3/6] Starting container..."
docker run -d \
  --name $CONTAINER_NAME \
  --memory="512m" \
  --memory-swap="1g" \
  -p 8080:8080 \
  $IMAGE_NAME

echo "Waiting for service to start..."
sleep 5

echo "[4/6] Collecting baseline benchmark..."
docker run --rm --network host jordi/ab -n 1000 -c 10 http://127.0.0.1:8080/ > "$OUTDIR/baseline_ab.txt"

echo "[5/6] Running memory pressure inside container..."
docker exec $CONTAINER_NAME stress-ng --vm 1 --vm-bytes 400m --timeout 30s &
STRESS_PID=$!

sleep 2

echo "Collecting benchmark under pressure..."
docker run --rm --network host jordi/ab -n 1000 -c 10 http://127.0.0.1:8080/ > "$OUTDIR/pressure_ab.txt"

wait $STRESS_PID || true

echo "[6/6] Saving memory stats..."
docker stats --no-stream $CONTAINER_NAME > "$OUTDIR/docker_stats.txt"
docker exec $CONTAINER_NAME cat /proc/meminfo > "$OUTDIR/meminfo.txt"
docker exec $CONTAINER_NAME cat /proc/vmstat > "$OUTDIR/vmstat_full.txt"