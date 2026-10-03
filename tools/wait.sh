#!/usr/bin/env bash
# Wait (max $2 s) until pattern $1 appears in any coop log, a Code Error dialog shows, or the game exits.
PAT=$1; MAX=${2:-60}; S="$LOCALAPPDATA/ZERO_Sievert"
for i in $(seq 1 $((MAX/2))); do
  grep -q -E "$PAT" "$S"/coop_*.log 2>/dev/null && { echo "MATCH after $((i*2))s"; break; }
  um win ps "ZERO" 2>/dev/null | grep -q "Code Error" && { echo "CODE ERROR dialog"; break; }
  tasklist | grep -qi "zero sievert" || { echo "game not running"; break; }
  sleep 2
done
