#!/bin/bash
set -e

source ./configs.sh

SWAP=$1
LEVEL=$2
STRESS_BYTES=${STRESS_LEVELS[$LEVEL]}

OUTDIR="results/swap_${SWAP}_${LEVEL}"
mkdir -p "$OUTDIR"

C1="service"
C2="stressor"
IMAGE="memory-pressure-app"

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

docker rm -f $C1 $C2 2>/dev/null || true

# Start service container
docker run -d \
  --name $C1 \
  --memory="$SERVICE_MEM" \
  --memory-swap="$SERVICE_SWAP" \
  -p 8080:8080 \
  $IMAGE

# Wait until service is ready
echo "[*] Waiting for service to be ready..."
sleep 5
# Start stress container
docker run -d \
  --name $C2 \
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


