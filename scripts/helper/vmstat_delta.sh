#!/bin/bash

BEFORE=$1
AFTER=$2

echo "Metric,Delta"

join <(sort $BEFORE) <(sort $AFTER) | while read key before after; do
    delta=$((after - before))
    echo "$key,$delta"
done

