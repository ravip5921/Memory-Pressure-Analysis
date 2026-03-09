#!/bin/bash
set -e

BASELINE=$1
CONTENDED=$2

DIR="results/docker/interference"
OUTDIR="$DIR/summarized_results"

mkdir -p "$OUTDIR"

HOST_DELTA="$DIR/host_vmstat_delta.csv"
C1_DELTA="$DIR/c1_vmstat_delta.csv"
C2_DELTA="$DIR/c2_vmstat_delta.csv"

CSV="$OUTDIR/summary.csv"

############################################################
# Extract RPS
############################################################

BASE_RPS=$(grep "Requests per second" "$BASELINE" | awk '{print $4}')
CONT_RPS=$(grep "Requests per second" "$CONTENDED" | awk '{print $4}')

SLOWDOWN=$(echo "$BASE_RPS / $CONT_RPS" | bc -l)

############################################################
# Helper to extract vmstat metric
############################################################

get_metric() {
    FILE=$1
    KEY=$2
    grep "^$KEY," "$FILE" | cut -d',' -f2
}

############################################################
# Host metrics
############################################################

PGSCAN=$(get_metric $HOST_DELTA pgscan_kswapd)
PGSCAN_DIRECT=$(get_metric $HOST_DELTA pgscan_direct)
PSWPOUT=$(get_metric $HOST_DELTA pswpout)
PSWPIN=$(get_metric $HOST_DELTA pswpin)
PGSTEAL_ANON=$(get_metric $HOST_DELTA pgsteal_anon)
PGSTEAL_FILE=$(get_metric $HOST_DELTA pgsteal_file)

############################################################
# Container metrics
############################################################

C1_MAJFAULT=$(get_metric $C1_DELTA pgmajfault)
C2_MAJFAULT=$(get_metric $C2_DELTA pgmajfault)

############################################################
# Write CSV
############################################################

echo "baseline_rps,contended_rps,slowdown,pgscan_kswapd,pgscan_direct,pswpout,pswpin,pgsteal_anon,pgsteal_file,c1_pgmajfault,c2_pgmajfault" > $CSV

echo "$BASE_RPS,$CONT_RPS,$SLOWDOWN,$PGSCAN,$PGSCAN_DIRECT,$PSWPOUT,$PSWPIN,$PGSTEAL_ANON,$PGSTEAL_FILE,$C1_MAJFAULT,$C2_MAJFAULT" >> $CSV

############################################################
# Print nice table
############################################################

echo
echo "===== Experiment Summary ====="
printf "%-20s %-10s\n" "Baseline RPS:" "$BASE_RPS"
printf "%-20s %-10s\n" "Contended RPS:" "$CONT_RPS"
printf "%-20s %-10s\n" "Slowdown:" "${SLOWDOWN}x"
echo
echo "Memory Pressure:"
printf "%-20s %-10s\n" "pgscan_kswapd:" "$PGSCAN"
printf "%-20s %-10s\n" "pgscan_direct:" "$PGSCAN_DIRECT"
printf "%-20s %-10s\n" "pswpout:" "$PSWPOUT"
printf "%-20s %-10s\n" "pswpin:" "$PSWPIN"
echo
echo "Reclaim Type:"
printf "%-20s %-10s\n" "pgsteal_anon:" "$PGSTEAL_ANON"
printf "%-20s %-10s\n" "pgsteal_file:" "$PGSTEAL_FILE"
echo
echo "Container Impact:"
printf "%-20s %-10s\n" "C1 major faults:" "$C1_MAJFAULT"
printf "%-20s %-10s\n" "C2 major faults:" "$C2_MAJFAULT"
echo
echo "CSV saved to:"
echo "$CSV"