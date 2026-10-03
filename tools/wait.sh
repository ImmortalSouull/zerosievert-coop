#!/usr/bin/env bash
# Wait (max $2 s) until pattern $1 appears in any coop log, or the game exits. Cheap checks only.
PAT=$1; MAX=${2:-60}; S="$LOCALAPPDATA/ZERO_Sievert"; START=$(date +%s)
while [ $(( $(date +%s) - START )) -lt "$MAX" ]; do
  grep -q -E "$PAT" "$S"/coop_*.log 2>/dev/null && { echo "MATCH after $(( $(date +%s) - START ))s"; exit 0; }
  grep -q "CRASH" "$S"/coop_*.log 2>/dev/null && { echo "CRASH"; grep -h CRASH "$S"/coop_*.log | head -3; exit 1; }
  tasklist | grep -qi "zero sievert" || { echo "game not running"; exit 1; }
  sleep 1
done
echo "TIMEOUT"
