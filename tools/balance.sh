#!/bin/bash
# balance.sh TAG MAP DIFF "SEEDS" [extra args]
# Plays zombie mode with nobody giving orders, once for each seed (two battles at a time), so a change
# to the balance is judged on several battles and not on one: the same battle swings by three waves
# from one run to the next. MAP town|office|city|factory, DIFF 0 easy, 1 normal, 2 hard.
# Logs go to ${BAL_DIR:-/tmp/bal}/TAG_MAP_DIFF_SEED.log; tools/balance_report.sh TAG prints the spread.
#   tools/balance.sh before office 1 "7 11 13"
TAG=$1; MAP=$2; DIFF=$3; SEEDS=$4; shift 4
cd "$(dirname "$0")/.."
OUT=${BAL_DIR:-/tmp/bal}; mkdir -p "$OUT"
for s in $SEEDS; do
  while [ "$(pgrep -c -x godot)" -ge "${BAL_JOBS:-2}" ]; do sleep 5; done
  nohup timeout 3300 godot --headless --path . --fixed-fps 60 -- --hordeplay --map=$MAP --diff=$DIFF --secs=2700 --seed=$s "$@" > "$OUT/${TAG}_${MAP}_${DIFF}_$s.log" 2>&1 &
  sleep 2
done
wait
